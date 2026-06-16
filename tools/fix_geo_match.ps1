# Fix sr2030_geo_match.json with correct lat/lon &rarr; grid coordinate conversion

$jsonDir = "C:\Users\werne\ProjetoZero\assets\data"
$regionsPath = Join-Path $jsonDir "sr2030_regions.json"
$geoPath = Join-Path $jsonDir "sr2030_geo_match.json"

$gridW = 320
$gridH = 200

$countryBounds = @{
    "USA" = @{LatMin=24.4; LatMax=49.4; LonMin=-125.0; LonMax=-66.9}
    "CAN" = @{LatMin=41.7; LatMax=83.1; LonMin=-141.0; LonMax=-52.6}
    "MEX" = @{LatMin=14.5; LatMax=32.7; LonMin=-118.4; LonMax=-86.7}
    "GTM" = @{LatMin=13.7; LatMax=17.8; LonMin=-92.2; LonMax=-88.2}
    "BLZ" = @{LatMin=15.9; LatMax=18.5; LonMin=-89.2; LonMax=-87.5}
    "SLV" = @{LatMin=13.1; LatMax=14.4; LonMin=-90.1; LonMax=-87.7}
    "HND" = @{LatMin=12.9; LatMax=16.5; LonMin=-89.3; LonMax=-82.3}
    "NIC" = @{LatMin=10.7; LatMax=15.0; LonMin=-87.7; LonMax=-82.4}
    "CRI" = @{LatMin=8.0; LatMax=11.2; LonMin=-85.9; LonMax=-82.5}
    "PAN" = @{LatMin=7.2; LatMax=9.7; LonMin=-83.0; LonMax=-77.2}
    "COL" = @{LatMin=-4.2; LatMax=12.5; LonMin=-79.0; LonMax=-66.9}
    "VEN" = @{LatMin=0.6; LatMax=12.2; LonMin=-73.4; LonMax=-59.8}
    "GUY" = @{LatMin=1.2; LatMax=8.5; LonMin=-61.4; LonMax=-56.5}
    "SUR" = @{LatMin=1.8; LatMax=6.0; LonMin=-58.1; LonMax=-54.0}
    "ECU" = @{LatMin=-5.0; LatMax=1.4; LonMin=-81.0; LonMax=-75.2}
    "PER" = @{LatMin=-18.3; LatMax=-0.5; LonMin=-81.3; LonMax=-68.7}
    "BRA" = @{LatMin=-33.8; LatMax=5.3; LonMin=-73.3; LonMax=-34.8}
    "BOL" = @{LatMin=-22.9; LatMax=-9.6; LonMin=-69.6; LonMax=-57.5}
    "PRY" = @{LatMin=-27.6; LatMax=-19.3; LonMin=-62.6; LonMax=-54.2}
    "URY" = @{LatMin=-35.0; LatMax=-30.1; LonMin=-58.4; LonMax=-53.1}
    "ARG" = @{LatMin=-55.1; LatMax=-21.8; LonMin=-73.6; LonMax=-53.6}
    "CHL" = @{LatMin=-56.0; LatMax=-17.5; LonMin=-76.0; LonMax=-66.4}
    "FRA" = @{LatMin=41.3; LatMax=51.1; LonMin=-4.8; LonMax=8.2}
    "ESP" = @{LatMin=35.9; LatMax=43.8; LonMin=-9.3; LonMax=4.3}
    "PRT" = @{LatMin=32.6; LatMax=42.2; LonMin=-9.5; LonMax=-6.2}
    "GBR" = @{LatMin=49.9; LatMax=60.9; LonMin=-8.2; LonMax=1.8}
    "IRL" = @{LatMin=51.4; LatMax=55.4; LonMin=-10.5; LonMax=-5.9}
    "NLD" = @{LatMin=50.7; LatMax=53.5; LonMin=3.3; LonMax=7.2}
    "BEL" = @{LatMin=49.5; LatMax=51.5; LonMin=2.5; LonMax=6.4}
    "LUX" = @{LatMin=49.4; LatMax=50.2; LonMin=5.7; LonMax=6.5}
    "DEU" = @{LatMin=47.3; LatMax=55.1; LonMin=5.9; LonMax=15.0}
    "CHE" = @{LatMin=45.8; LatMax=47.8; LonMin=5.9; LonMax=10.5}
    "AUT" = @{LatMin=46.4; LatMax=49.0; LonMin=9.5; LonMax=17.2}
    "POL" = @{LatMin=49.0; LatMax=54.8; LonMin=14.1; LonMax=24.1}
    "CZE" = @{LatMin=48.5; LatMax=51.1; LonMin=12.1; LonMax=18.9}
    "SVK" = @{LatMin=47.7; LatMax=49.6; LonMin=16.8; LonMax=22.6}
    "HUN" = @{LatMin=45.7; LatMax=48.6; LonMin=16.1; LonMax=22.9}
    "DNK" = @{LatMin=54.6; LatMax=57.7; LonMin=8.1; LonMax=15.2}
    "NOR" = @{LatMin=57.9; LatMax=71.2; LonMin=4.6; LonMax=31.2}
    "SWE" = @{LatMin=55.3; LatMax=69.1; LonMin=11.1; LonMax=24.2}
    "FIN" = @{LatMin=59.8; LatMax=70.1; LonMin=20.6; LonMax=31.6}
    "ISL" = @{LatMin=63.3; LatMax=66.6; LonMin=-24.5; LonMax=-13.5}
    "RUS" = @{LatMin=41.2; LatMax=81.9; LonMin=19.6; LonMax=-169.0}
    "EST" = @{LatMin=57.5; LatMax=59.7; LonMin=21.8; LonMax=28.2}
    "LVA" = @{LatMin=55.7; LatMax=58.1; LonMin=20.9; LonMax=28.2}
    "LTU" = @{LatMin=53.9; LatMax=56.4; LonMin=20.9; LonMax=26.8}
    "BLR" = @{LatMin=51.3; LatMax=56.2; LonMin=23.2; LonMax=32.8}
    "UKR" = @{LatMin=44.4; LatMax=52.4; LonMin=22.1; LonMax=40.2}
    "ROU" = @{LatMin=43.6; LatMax=48.3; LonMin=20.3; LonMax=29.7}
    "BGR" = @{LatMin=41.2; LatMax=44.2; LonMin=22.3; LonMax=28.6}
    "GRC" = @{LatMin=34.8; LatMax=41.7; LonMin=19.4; LonMax=29.6}
    "ITA" = @{LatMin=36.6; LatMax=47.1; LonMin=6.6; LonMax=18.5}
    "HRV" = @{LatMin=42.4; LatMax=46.6; LonMin=13.5; LonMax=19.4}
    "SRB" = @{LatMin=42.2; LatMax=46.2; LonMin=18.8; LonMax=23.0}
    "ALB" = @{LatMin=39.6; LatMax=42.7; LonMin=19.2; LonMax=21.1}
    "MKD" = @{LatMin=40.8; LatMax=42.4; LonMin=20.4; LonMax=23.0}
    "BIH" = @{LatMin=42.5; LatMax=45.3; LonMin=15.7; LonMax=19.6}
    "MNE" = @{LatMin=41.8; LatMax=43.6; LonMin=18.4; LonMax=20.4}
    "SVN" = @{LatMin=45.4; LatMax=46.9; LonMin=13.4; LonMax=16.6}
    "MAR" = @{LatMin=27.7; LatMax=35.9; LonMin=-13.2; LonMax=-1.0}
    "DZA" = @{LatMin=18.9; LatMax=37.1; LonMin=-8.7; LonMax=12.0}
    "TUN" = @{LatMin=30.2; LatMax=37.5; LonMin=7.5; LonMax=11.6}
    "LBY" = @{LatMin=19.5; LatMax=33.2; LonMin=9.3; LonMax=25.0}
    "EGY" = @{LatMin=22.0; LatMax=31.7; LonMin=24.7; LonMax=37.0}
    "SDN" = @{LatMin=8.7; LatMax=22.2; LonMin=21.8; LonMax=38.6}
    "SSD" = @{LatMin=3.5; LatMax=12.2; LonMin=23.4; LonMax=35.9}
    "ETH" = @{LatMin=3.4; LatMax=14.9; LonMin=33.0; LonMax=48.0}
    "ERI" = @{LatMin=12.4; LatMax=18.1; LonMin=36.4; LonMax=43.3}
    "DJI" = @{LatMin=10.9; LatMax=12.7; LonMin=41.8; LonMax=43.4}
    "SOM" = @{LatMin=-1.8; LatMax=12.0; LonMin=41.0; LonMax=51.4}
    "KEN" = @{LatMin=-4.7; LatMax=5.0; LonMin=33.9; LonMax=41.9}
    "UGA" = @{LatMin=-1.5; LatMax=4.2; LonMin=29.5; LonMax=35.0}
    "TZA" = @{LatMin=-11.7; LatMax=-1.0; LonMin=29.3; LonMax=40.5}
    "RWA" = @{LatMin=-2.9; LatMax=-1.0; LonMin=28.9; LonMax=30.9}
    "BDI" = @{LatMin=-4.5; LatMax=-2.3; LonMin=28.9; LonMax=30.8}
    "MWI" = @{LatMin=-17.1; LatMax=-9.4; LonMin=32.6; LonMax=35.9}
    "ZMB" = @{LatMin=-18.1; LatMax=-8.2; LonMin=22.0; LonMax=33.7}
    "ZWE" = @{LatMin=-22.4; LatMax=-15.6; LonMin=25.2; LonMax=33.1}
    "MOZ" = @{LatMin=-26.9; LatMax=-10.5; LonMin=30.2; LonMax=40.9}
    "MDG" = @{LatMin=-25.6; LatMax=-11.9; LonMin=43.2; LonMax=50.5}
    "AGO" = @{LatMin=-18.0; LatMax=-4.4; LonMin=11.7; LonMax=24.1}
    "NAM" = @{LatMin=-28.9; LatMax=-17.0; LonMin=11.7; LonMax=25.3}
    "BWA" = @{LatMin=-26.9; LatMax=-17.8; LonMin=19.9; LonMax=29.4}
    "ZAF" = @{LatMin=-34.8; LatMax=-22.1; LonMin=16.5; LonMax=32.9}
    "SWZ" = @{LatMin=-27.1; LatMax=-25.7; LonMin=30.8; LonMax=32.1}
    "LSO" = @{LatMin=-30.6; LatMax=-28.6; LonMin=27.1; LonMax=29.5}
    "NGA" = @{LatMin=4.3; LatMax=13.9; LonMin=2.7; LonMax=14.7}
    "GHA" = @{LatMin=4.7; LatMax=11.2; LonMin=-3.3; LonMax=1.2}
    "CIV" = @{LatMin=4.3; LatMax=10.7; LonMin=-8.6; LonMax=-2.5}
    "LBR" = @{LatMin=4.3; LatMax=8.5; LonMin=-11.5; LonMax=-7.4}
    "SLE" = @{LatMin=6.9; LatMax=10.0; LonMin=-13.3; LonMax=-10.3}
    "GIN" = @{LatMin=7.2; LatMax=12.7; LonMin=-15.1; LonMax=-7.7}
    "SEN" = @{LatMin=12.3; LatMax=16.7; LonMin=-17.5; LonMax=-11.3}
    "GMB" = @{LatMin=13.0; LatMax=13.8; LonMin=-16.8; LonMax=-13.8}
    "MLI" = @{LatMin=10.1; LatMax=25.0; LonMin=-12.2; LonMax=4.3}
    "BFA" = @{LatMin=9.4; LatMax=15.1; LonMin=-5.5; LonMax=2.4}
    "NER" = @{LatMin=11.7; LatMax=23.5; LonMin=0.2; LonMax=16.0}
    "TCD" = @{LatMin=7.5; LatMax=23.5; LonMin=13.5; LonMax=24.0}
    "CMR" = @{LatMin=1.7; LatMax=13.1; LonMin=8.4; LonMax=16.2}
    "CAF" = @{LatMin=3.0; LatMax=11.0; LonMin=14.4; LonMax=27.5}
    "GAB" = @{LatMin=-3.9; LatMax=2.3; LonMin=8.5; LonMax=14.5}
    "COG" = @{LatMin=-5.0; LatMax=3.7; LonMin=11.2; LonMax=18.6}
    "COD" = @{LatMin=-13.5; LatMax=5.4; LonMin=12.2; LonMax=31.3}
    "SAU" = @{LatMin=16.3; LatMax=32.2; LonMin=34.5; LonMax=55.7}
    "YEM" = @{LatMin=12.5; LatMax=19.0; LonMin=42.5; LonMax=54.0}
    "OMN" = @{LatMin=16.6; LatMax=26.4; LonMin=52.0; LonMax=60.0}
    "ARE" = @{LatMin=22.6; LatMax=26.1; LonMin=51.6; LonMax=56.4}
    "QAT" = @{LatMin=24.5; LatMax=26.2; LonMin=50.7; LonMax=51.7}
    "BHR" = @{LatMin=25.8; LatMax=26.3; LonMin=50.4; LonMax=50.7}
    "KWT" = @{LatMin=28.5; LatMax=30.1; LonMin=46.5; LonMax=48.5}
    "IRQ" = @{LatMin=29.1; LatMax=37.3; LonMin=38.8; LonMax=48.6}
    "IRN" = @{LatMin=25.0; LatMax=39.8; LonMin=44.0; LonMax=63.3}
    "TUR" = @{LatMin=35.8; LatMax=42.1; LonMin=25.7; LonMax=44.8}
    "SYR" = @{LatMin=32.3; LatMax=37.3; LonMin=35.6; LonMax=42.4}
    "JOR" = @{LatMin=29.2; LatMax=33.4; LonMin=34.9; LonMax=39.3}
    "LBN" = @{LatMin=33.0; LatMax=34.7; LonMin=35.1; LonMax=36.6}
    "ISR" = @{LatMin=29.5; LatMax=33.3; LonMin=34.2; LonMax=35.9}
    "AFG" = @{LatMin=29.4; LatMax=38.5; LonMin=60.5; LonMax=75.1}
    "PAK" = @{LatMin=23.7; LatMax=37.1; LonMin=60.9; LonMax=77.8}
    "IND" = @{LatMin=6.7; LatMax=37.1; LonMin=68.2; LonMax=97.4}
    "NPL" = @{LatMin=26.3; LatMax=30.5; LonMin=80.0; LonMax=88.2}
    "BTN" = @{LatMin=26.7; LatMax=28.4; LonMin=88.7; LonMax=92.1}
    "BGD" = @{LatMin=20.6; LatMax=26.6; LonMin=88.0; LonMax=92.7}
    "MMR" = @{LatMin=9.8; LatMax=28.5; LonMin=92.2; LonMax=101.2}
    "THA" = @{LatMin=5.6; LatMax=20.5; LonMin=97.3; LonMax=105.6}
    "LAO" = @{LatMin=13.9; LatMax=22.5; LonMin=100.1; LonMax=107.6}
    "KHM" = @{LatMin=10.4; LatMax=14.7; LonMin=102.3; LonMax=107.6}
    "VNM" = @{LatMin=8.4; LatMax=23.4; LonMin=102.1; LonMax=109.5}
    "MYS" = @{LatMin=0.9; LatMax=7.4; LonMin=99.6; LonMax=104.2}
    "SGP" = @{LatMin=1.2; LatMax=1.5; LonMin=103.6; LonMax=104.0}
    "IDN" = @{LatMin=-10.4; LatMax=5.9; LonMin=95.0; LonMax=141.0}
    "PHL" = @{LatMin=4.6; LatMax=18.6; LonMin=116.9; LonMax=126.6}
    "CHN" = @{LatMin=18.2; LatMax=53.6; LonMin=73.5; LonMax=135.1}
    "TWN" = @{LatMin=21.9; LatMax=25.3; LonMin=119.3; LonMax=122.0}
    "MNG" = @{LatMin=41.6; LatMax=52.1; LonMin=87.8; LonMax=119.9}
    "PRK" = @{LatMin=37.7; LatMax=43.0; LonMin=124.2; LonMax=130.7}
    "KOR" = @{LatMin=33.0; LatMax=38.6; LonMin=124.6; LonMax=129.6}
    "JPN" = @{LatMin=30.3; LatMax=45.5; LonMin=129.5; LonMax=145.8}
    "AUS" = @{LatMin=-43.6; LatMax=-10.7; LonMin=112.9; LonMax=153.6}
    "NZL" = @{LatMin=-47.3; LatMax=-34.4; LonMin=166.4; LonMax=178.5}
    "PNG" = @{LatMin=-11.7; LatMax=-2.5; LonMin=140.8; LonMax=155.9}
    "FJI" = @{LatMin=-18.3; LatMax=-16.0; LonMin=177.0; LonMax=-180.0}
    "CUB" = @{LatMin=19.8; LatMax=23.2; LonMin=-85.0; LonMax=-74.1}
    "HAI" = @{LatMin=18.0; LatMax=20.2; LonMin=-74.5; LonMax=-71.6}
    "DOM" = @{LatMin=17.5; LatMax=19.9; LonMin=-72.0; LonMax=-68.3}
    "JAM" = @{LatMin=17.7; LatMax=18.5; LonMin=-78.4; LonMax=-76.2}
    "PRI" = @{LatMin=17.9; LatMax=18.5; LonMin=-67.3; LonMax=-65.6}
    "KAZ" = @{LatMin=40.9; LatMax=55.4; LonMin=46.5; LonMax=87.3}
    "UZB" = @{LatMin=37.2; LatMax=45.6; LonMin=56.0; LonMax=73.1}
    "TKM" = @{LatMin=35.1; LatMax=42.8; LonMin=52.4; LonMax=66.7}
    "KGZ" = @{LatMin=39.2; LatMax=43.3; LonMin=69.2; LonMax=80.3}
    "TJK" = @{LatMin=36.7; LatMax=41.0; LonMin=67.3; LonMax=75.2}
    "GEO" = @{LatMin=41.0; LatMax=43.6; LonMin=40.0; LonMax=46.7}
    "ARM" = @{LatMin=38.8; LatMax=41.3; LonMin=43.4; LonMax=46.6}
    "AZE" = @{LatMin=38.4; LatMax=41.9; LonMin=44.8; LonMax=50.7}
    "GRL" = @{LatMin=59.8; LatMax=83.6; LonMin=-73.0; LonMax=-12.0}
    "LKA" = @{LatMin=5.9; LatMax=9.9; LonMin=79.7; LonMax=81.9}
    "WSM" = @{LatMin=-14.1; LatMax=-13.4; LonMin=-172.8; LonMax=-171.4}
    "TON" = @{LatMin=-21.5; LatMax=-15.5; LonMin=-175.4; LonMax=-173.7}
    "VUT" = @{LatMin=-20.2; LatMax=-13.0; LonMin=166.5; LonMax=170.3}
    "SLB" = @{LatMin=-12.0; LatMax=-5.0; LonMin=155.5; LonMax=170.2}
}

$regionsText = Get-Content -Path $regionsPath -Raw -Encoding UTF8
$regions = $regionsText | ConvertFrom-Json

$parts = @()
$parts += '{"description":"Bounding boxes for 320x200 grid (corrected)","countries":['
$first = $true

$missing = 0
$found = 0

foreach ($region in $regions.countries) {
    $cid = [int]$region.id
    $tag = $region.tag
    $name = $region.name

    if ($null -eq $tag -or -not $countryBounds.ContainsKey($tag)) {
        Write-Warning "No bounds for tag=$tag, id=$cid, name=$name"
        $missing++
        continue
    }

    $b = $countryBounds[$tag]
    $found++

    # Handle wrap-around (e.g. Russia crosses 180 degrees)
    $lonMin = $b.LonMin
    $lonMax = $b.LonMax
    if ($lonMax -lt $lonMin) { $lonMax += 360.0 }

    $cMin = [math]::Floor(($lonMin + 180.0) / 360.0 * 320)
    $cMax = [math]::Ceiling(($lonMax + 180.0) / 360.0 * 320) - 1
    $rMin = [math]::Floor((90.0 - $b.LatMax) / 180.0 * 200)
    $rMax = [math]::Ceiling((90.0 - $b.LatMin) / 180.0 * 200) - 1

    $cMin = [math]::Max(0, [int]$cMin)
    $cMax = [math]::Min(319, [int]$cMax)
    $rMin = [math]::Max(0, [int]$rMin)
    $rMax = [math]::Min(199, [int]$rMax)

    if (-not $first) { $parts += ',' }
    $first = $false
    $parts += '{"id":'
    $parts += $cid
    $parts += ',"boxes":['
    $parts += $cMin; $parts += ','
    $parts += $cMax; $parts += ','
    $parts += $rMin; $parts += ','
    $parts += $rMax
    $parts += ']}'

    Write-Host "$tag ($name): cols $cMin-$cMax, rows $rMin-$rMax"
}

$parts += ']}'
$json = $parts -join ''

$utf8 = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($geoPath, $json, $utf8)

Write-Host "Written $found countries ($missing missing) to $geoPath"
