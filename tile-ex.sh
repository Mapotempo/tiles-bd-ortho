DEP=$1
z1=${2:-15}
z2=${3:-16}
z3=${4:-17}

mkdir -p ${DEP} && cd ${DEP}

# Ne prend que la dernière année et qu'une seule projection
MILL=`cat ../url_list | grep "_D${DEP}_" | sed -e "s/.*E080_\([A-Z0-9]*\)_D${DEP}_\(2...\).*/\1_D${DEP}_\2/" | uniq | tail -n 1`
cat ../url_list | grep "${MILL}" | xargs -n 1 wget

# D009 3.57G 3.18MB/s in 58m 43s
##Téléchargés : 244 fichiers, 281G en 1d 6h 42m 20s (2,60 MB/s)

ls *.7z* | grep "_D${DEP}_" | egrep '.7z(.001)?$' | xargs -n1 7zr -y x && rm *_D${DEP}_*.7z*

# D009 3.8G
##242 Go decomp au total

echo "
cd /home/datafolder
find -name *.jp2 -o -name *.tif | grep */ > list
gdalbuildvrt -srcnodata '255 255 255' -vrtnodata '0 0 0' -input_file_list list virt.vrt

# Niveau de zoom pour le LAMB93
gdal_translate -co TILE_FORMAT=JPEG -co QUALITY=70 -co RESAMPLING=average -outsize 50% 50% virt.vrt tiles-${DEP}-${z3}.mbtiles -of MBTILES
gdal_translate -co TILE_FORMAT=JPEG -co QUALITY=70 -co RESAMPLING=average -outsize 25% 25% virt.vrt tiles-${DEP}-${z2}.mbtiles -of MBTILES
gdal_translate -co TILE_FORMAT=JPEG -co QUALITY=70 -co RESAMPLING=average -outsize 12.5% 12.5% virt.vrt tiles-${DEP}-${z1}.mbtiles -of MBTILES
" | docker run -v `pwd`:/home/datafolder -i --rm geographica/gdal2:2.3.1 /bin/bash

DEP_=`echo ${DEP} | sed -e 's/^0//'`

jq -e ".features[].properties | select(.code == \"${DEP_}\")" < ../departements-avec-outre-mer.geojson
if [[ $? != 0 ]]; then
  # Département non trouvé, on prend tout
  for z in ${z1} ${z2} ${z3}; do
    mv tiles-${DEP}-${z}.mbtiles ..
  done
else
  echo "
  cd /home/datafolder
  for z in ${z1} ${z2} ${z3}; do
    ./mbtiles-extracts/mbtiles-extracts ${DEP}/tiles-${DEP}-\${z}.mbtiles departements-avec-outre-mer.geojson code
    mv \`find ${DEP}/tiles-${DEP}-\${z}/ -iname ${DEP_}.mbtiles\` tiles-${DEP}-\${z}.mbtiles
    rm -dr ${DEP}/tiles-${DEP}-\${z}
  done
  " | docker run -v `pwd`/..:/home/datafolder -i --rm node:10-slim /bin/bash
fi
