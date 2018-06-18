Creation of tiles for the web from the orthophotographies of BD Ortho® from OpenData
====================================================================================

This project is to build MBtiles from BD Ortho® from http://professionnels.ign.fr/bdortho-5m

The process explenation of building can be read, in French, at https://medium.com/@frederic.rodrigo/cr%C3%A9ation-de-tuiles-pour-le-web-depuis-les-orthophotographies-de-la-bd-ortho-en-licence-ouverte-f47503475128

The result MBTiles are available online at https://www.data.gouv.fr/fr/datasets/pyramide-de-tuiles-depuis-la-bd-ortho-r

A demo slippy map is available at https://maps.mapotempo.com/styles/satellite-hybrid/#12/42.5744/2.0985

Download BD Ortho® at 5 m
-------------------------

Download the files list.
```bash
mkdir bd5m && cd bd5m
# List archives
curl professionnels.ign.fr/bdortho-5m | grep -Po '(?<=href=")[^"]*' | grep '.7z' > list7z
# Get number of files
cat list7z | wc -l
# Number of files per departements
cat list7z | sed -e 's/.*\(D[0-9]\?[0-9][AB0-9]\).*/\1/g' | sort | uniq -c | sort -n > list7z-par-dep
cat list7z-par-dep
```

Download the content, +64G in 8h 34m 0s (2.14 MB/s).
```bash
wget -i list7z
```

Check we get all files.
```bash
ls *.7z* | sed -e 's/.*\(D[0-9]\?[0-9][AB0-9]\).*/\1/g' | sort | uniq -c | sort -n > list7z-par-dep-local
diff -ruN0 list7z-par-dep list7z-par-dep-local
```

Extract the archives, -71G in 66m24.306s.
```bash
ls *.7z | xargs -n1 7zr x
# 3m44.071s +6G
ls *.7z.001 | xargs -n1 7zr x
```

Check the number of departements.
```bash
cat list7z | sed -e 's/.*\(D[0-9]\?[0-9][AB0-9]\).*/\1/g' | sort | uniq -c | sort -n | wc -l
ls -d */ | wc -l
```

If OK we can delete the 7z files, -64G.
```bash
# rm *.7z*
```

Build virtual descriptor
------------------------

If required, run the following in a docker container to use GDAL 2.
```bash
export DATAFOLDER="-v `pwd`:/home/datafolder"
docker run $DATAFOLDER --name gdal2 -it --rm geographica/gdal2:2.2.3 /bin/bash
apt update && apt install -y parallel
cd /home/datafolder
```

Build the virtual descriptor.
```bash
for p in LAMB93 RGAF09UTM20 RGM04UTM38S RGR92UTM40S RGSPM06U21 UTM20W84GUAD UTM22RGFG95 UTM01SW84; do
  gdalbuildvrt -allow_projection_difference -srcnodata "255 255 255" -vrtnodata "0 0 0" virt-$p.vrt `find -name *.jp2 -o -name *.tif | grep $p`
done
```

Build MBTiles
-------------

If required, run the following in a docker container to use GDAL 2.
```bash
export DATAFOLDER="-v `pwd`:/home/datafolder"
docker run $DATAFOLDER --name gdal2 -it --rm geographica/gdal2:2.2.3 /bin/bash
apt update && apt install -y parallel
cd /home/datafolder
```

Build tiles for zoom 9 up to 14 (or 15 or 16 depends of projections). With 8CPUs, takes 20h (including 14h for LAMB93 zoom 14), +8.5G.
```bash
cat <(
for p in LAMB93; do
  for i in "100% 14" "50% 13" "25% 12" "12.5% 11" "6.25% 10" "3,125% 9"; do
    echo gdal_translate -co TILE_FORMAT=JPEG -co QUALITY=90 -co RESAMPLING=average -outsize `echo "$i" | cut -d ' ' -f 1` `echo "$i" | cut -d ' ' -f 1` virt-$p.vrt tiles`echo "$i" | cut -d ' ' -f 2`-$p.mbtiles -of MBTILES
  done
done
for p in RGSPM06U21; do
  for i in "200% 15" "100% 14" "50% 13" "25% 12" "12.5% 11" "6.25% 10" "3,125% 9"; do
    echo gdal_translate -co TILE_FORMAT=JPEG -co QUALITY=90 -co RESAMPLING=average -outsize `echo "$i" | cut -d ' ' -f 1` `echo "$i" | cut -d ' ' -f 1` virt-$p.vrt tiles`echo "$i" | cut -d ' ' -f 2`-$p.mbtiles -of MBTILES
  done
done
for p in RGM04UTM38S RGR92UTM40S UTM20W84GUAD UTM22RGFG95 UTM01SW84; do
  for i in "200% 16" "100% 15" "50% 14" "25% 13" "12.5% 12" "6.25% 11" "3,125% 10" "1.5625% 9"; do
    echo gdal_translate -co TILE_FORMAT=JPEG -co QUALITY=90 -co RESAMPLING=average -outsize `echo "$i" | cut -d ' ' -f 1` `echo "$i" | cut -d ' ' -f 1` virt-$p.vrt tiles`echo "$i" | cut -d ' ' -f 2`-$p.mbtiles -of MBTILES
  done
done
for p in RGAF09UTM20; do
  for i in "100% 15" "50% 14" "25% 13" "12.5% 12" "6.25% 11" "3,125% 10" "1.5625% 9"; do
    echo gdal_translate -co TILE_FORMAT=JPEG -co QUALITY=90 -co RESAMPLING=average -outsize `echo "$i" | cut -d ' ' -f 1` `echo "$i" | cut -d ' ' -f 1` virt-$p.vrt tiles`echo "$i" | cut -d ' ' -f 2`-$p.mbtiles -of MBTILES
  done
done
) | parallel
```

Merge MBTiles
-------------

Get a script to merge MBTiles and fix it.
```bash
wget https://raw.githubusercontent.com/mapbox/mbutil/5e1ac74fdf7b0f85cfbbc245481e1d6b4d0f440d/patch
sed -e 's/REPLACE INTO map SELECT \* FROM source.map/REPLACE INTO tiles SELECT * FROM source.tiles/' -i patch
sed -e 's/REPLACE INTO images SELECT \* FROM source.images;//' -i patch
```

Merge the MBTiles, +8.5G.
```bash
for p in LAMB93; do
  cp tiles14-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles13-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles12-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles11-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles10-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles9-$p.mbtiles tiles-$p.mbtiles

  sqlite3 tiles-$p.mbtiles "update metadata set value=9 where name='minzoom'"
  sqlite3 tiles-$p.mbtiles "update metadata set value='IGN - BD ORTHO' where name='name'"
  sqlite3 tiles-$p.mbtiles "update metadata set value='Orthophotographie de l''IGN - Licence Ouverte version 2.0' where name='description'"
  sqlite3 tiles-$p.mbtiles "update metadata set value='baselayer' where name='type'"
done

for p in RGSPM06U21; do
  cp tiles15-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles14-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles13-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles12-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles11-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles10-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles9-$p.mbtiles tiles-$p.mbtiles

  sqlite3 tiles-$p.mbtiles "update metadata set value=9 where name='minzoom'"
  sqlite3 tiles-$p.mbtiles "update metadata set value='IGN - BD ORTHO' where name='name'"
  sqlite3 tiles-$p.mbtiles "update metadata set value='Orthophotographie de l''IGN - Licence Ouverte version 2.0' where name='description'"
  sqlite3 tiles-$p.mbtiles "update metadata set value='baselayer' where name='type'"
done

for p in RGM04UTM38S RGR92UTM40S UTM20W84GUAD UTM22RGFG95 UTM01SW84; do
  cp tiles16-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles15-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles14-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles13-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles12-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles11-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles10-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles9-$p.mbtiles tiles-$p.mbtiles

  sqlite3 tiles-$p.mbtiles "update metadata set value=9 where name='minzoom'"
  sqlite3 tiles-$p.mbtiles "update metadata set value='IGN - BD ORTHO' where name='name'"
  sqlite3 tiles-$p.mbtiles "update metadata set value='Orthophotographie de l''IGN - Licence Ouverte version 2.0' where name='description'"
  sqlite3 tiles-$p.mbtiles "update metadata set value='baselayer' where name='type'"
done

for p in RGAF09UTM20; do
  cp tiles15-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles14-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles13-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles12-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles11-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles10-$p.mbtiles tiles-$p.mbtiles
  bash patch tiles9-$p.mbtiles tiles-$p.mbtiles

  sqlite3 tiles-$p.mbtiles "update metadata set value=9 where name='minzoom'"
  sqlite3 tiles-$p.mbtiles "update metadata set value='IGN - BD ORTHO' where name='name'"
  sqlite3 tiles-$p.mbtiles "update metadata set value='Orthophotographie de l''IGN - Licence Ouverte version 2.0' where name='description'"
  sqlite3 tiles-$p.mbtiles "update metadata set value='baselayer' where name='type'"
done
```

MBtiles by zoom level can be delete, -8.5G.
```bash
# rm tiles?*-*.mbtiles
```
