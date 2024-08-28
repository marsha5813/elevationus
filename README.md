# elevationus
Retrieves elevation data for US geographies. Built on [tigris](https://github.com/walkerke/tigris) and [elevatr](https://cran.r-project.org/web/packages/elevatr/index.html). 

get_elevation_data() takes a state, county or tract fips code and returns a map, a gridded raster of elevation data, raw elevation data and an estimate of mean elevation across the geography. 

get_elevation_data_batch() take a state FIPS code and returns elevation data for counties or tracts within that state. Elevation data includes the mean elevation for the substate geography and also the elevation at the [center of population](https://www.census.gov/geographies/reference-files/time-series/geo/centers-population.html). The center of population elevation helps account for the fact that population density and elevation are sometimes inversely correlated (e.g., a situation where the county includes a mountain and a valley but most people live in the valley).

## Installation
```
install.packages("devtools")
devtools::install_github("marsha5813/elevationus")
```

## Examples
### Get elevation data for the state of Oregon
```
library(elevationus)
elev <- get_elevation_data(level = "state", geoid = "41")
print(paste("Mean elevation:",elev$elevation_mean,"meters"))
elev$map
```
[1] "Mean elevation: 1073 meters"
![image](images/oregon.png)

### Get elevation for just one county. 
Increase resolution to 5 arc seconds.
```
elev <- get_elevation_data(level = "county", geoid = "24021", z = 10)
print(paste("Mean elevation:",elev$elevation_mean,"meters"))
elev$map
```
"Mean elevation: 183 meters"
![image](images/fredco.png)

### Get elevation for just one tract
Notice the pixelated elevation data at 5 arc seconds
```
elev <- get_elevation_data(level = "tract", geoid = "24510200100", z = 10)
print(paste("Mean elevation:",elev$elevation_mean,"meters"))
elev$map
```
"Mean elevation: 51 meters"
![image](images/tract_z10.png)

### Get elevation for just one tract at higher resolution
Dial resolution up to 1/3 arc seconds
```
elev <- get_elevation_data(level = "tract", geoid = "24510200100", z = 14)
elev$map
```
![image](images/tract_z14.png)

### Get elevation data for all counties in Maryland
```
get_elevation_data_batch(level = "county", state = "24")
```
|   | GEOID | NAMELSAD            | STATE_NAME | elevation_popcenter | elevation_popcenter |
|---|-------|---------------------|------------|---------------------|---------------------|
| 1 | 24001 | Allegany County     | Maryland   | 505                 | 382                 |
| 2 | 24003 | Anne Arundel County | Maryland   | 30                  | 29                  |
| 3 | 24005 | Baltimore County    | Maryland   | 138                 | 130                 |
| 4 | 24009 | Calvert County      | Maryland   | 45                  | 27                  |
| 5 | 24011 | Caroline County     | Maryland   | 13                  | 15                  |
...

### Get elevation data for all tracts in Maryland
```
get_elevation_data_batch(level = "tract", state = "24")
```
|   | GEOID       | NAMELSAD       | NAMELSADCO      | STATE_NAME | elevation_popcenter | elevation_mean |
|---|-------------|----------------|-----------------|------------|---------------------|----------------|
| 1 | 24001000100 | Census Tract 1 | Allegany County | Maryland   | 381                 | 306            |
| 2 | 24001000200 | Census Tract 2 | Allegany County | Maryland   | 366                 | 311            |
| 3 | 24001000500 | Census Tract 5 | Allegany County | Maryland   | 241                 | 237            |
| 4 | 24001000600 | Census Tract 6 | Allegany County | Maryland   | 246                 | 224            |
...

### Get elevation for tracts in Allegany County, Maryland
```
get_elevation_data_batch(level = "tract", state = "24", county = "001")
```
(table not shown)

## Notes
The 'z' argument ranges from 0 to 16 and is passed to [elevatr::get_elev_raster()](https://rdrr.io/cran/elevatr/man/get_elev_raster.html). See the [tilezen documentation](https://github.com/tilezen/joerd/blob/master/docs/data-sources.md) for data sources and resolutions returned at each level of z.

## Roadmap
### Future features
* Option for whole nation

### Future fixes
* Handle imports more carefully. See function conflicts. Import specific functions rather than whole namespaces.
