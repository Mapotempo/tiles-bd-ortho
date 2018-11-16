Récupère la liste de toutes les archives des orthophotographies disponibles.

```bash
curl http://professionnels.ign.fr/bdortho-50cm-par-departements | grep -Po '(?<=href=")[^"]*' | grep '.7z' | sed -e 's_^//_https://_' | sort | grep '\$' | grep 'BDORTHO-JP2_PACK' > url_list
```

Prepare mbtiles-extracts
------------------------
```bash
git clone https://github.com/mapbox/mbtiles-extracts.git
export DATAFOLDER="-v `pwd`:/home/datafolder"
docker run $DATAFOLDER --name node -it --rm node:10-slim /bin/bash
cd /home/datafolder/mbtiles-extracts
npm install
exit
```

```bash
wget https://raw.githubusercontent.com/gregoiredavid/france-geojson/master/departements-avec-outre-mer.geojson
```

Run
---
```bash
cat <(
for DEP in 005 008 014 015 021 022 025 027 029 02A 02B 030 031 032 034 035 039 042 043 045 046 048 049 050 051 052 053 056 059 061 062 063 065 066 067 068 072 076 081 082 083 084 085; do
  echo "./tile-ex.sh $DEP 15 16 17 > ${DEP}.log && rm -dr ${DEP}"
done
) | parallel -j 6

cat <(
for DEP in 971 972 978; do
  echo "./tile-ex.sh $DEP 16 17 18 > ${DEP}.log && rm -dr ${DEP}"
done
) | parallel -j 6
```

Merge
-----
```bash
wget https://raw.githubusercontent.com/mapbox/mbutil/5e1ac74fdf7b0f85cfbbc245481e1d6b4d0f440d/patch
sed -e 's/REPLACE INTO map SELECT \* FROM source.map/REPLACE INTO tiles SELECT * FROM source.tiles/' -i patch
sed -e 's/REPLACE INTO images SELECT \* FROM source.images;//' -i patch
```

```bash
for z in 15 16 17; do
  cp tiles-978-16.mbtiles tiles-${z}.mbtiles
  sqlite3 tiles-${z}.mbtiles "delete from tiles"
  for m in `find . -name "tiles-???-${z}.mbtiles"`; do
    bash patch $m tiles-${z}.mbtiles
  done
done

for z in 18; do
  cp tiles-978-16.mbtiles tiles-${z}.mbtiles
  sqlite3 tiles-${z}.mbtiles "delete from tiles"
  for m in `find . -name "tiles-???-${z}.mbtiles"`; do
    bash patch $m tiles-${z}.mbtiles
  done
done

for z in 15 16 17; do
  sqlite3 tiles-${z}.mbtiles "update metadata set value=${z} where name='maxzoom'"
  sqlite3 tiles-${z}.mbtiles "update metadata set value=${z} where name='minzoom'"
  sqlite3 tiles-${z}.mbtiles "delete from metadata where name='bounds'"
  sqlite3 tiles-${z}.mbtiles "update metadata set value='IGN - BD ORTHO' where name='name'"
  sqlite3 tiles-${z}.mbtiles "update metadata set value='Orthophotographie de l''IGN - Licence Ouverte version 2.0' where name='description'"
  sqlite3 tiles-${z}.mbtiles "update metadata set value='baselayer' where name='type'"
done
```
