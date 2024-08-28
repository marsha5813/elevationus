#' Retrieve elevation data for all substate geographies within a state
#'
#' @param level Character. One of "state", "county" or "tract"
#' @param state Character. Two-digit FIPS code for a state.
#' @param county Character. Optional. If level = "tract", county can be set to a
#' three-digit county fips code (e.g., "001") to limit only to tracts within than county.
#' @param year Numeric. Year for the geographic boundaries.
#'  Defaults to 2022.
#' @param resolution Character. Resolution for the cartographic
#'  boundary file retrieved by tigris::. Defaults to "500K". Other options are "5m" (1:5 million) and "20m" (1:20  million).
#' @param z Resolution used by elevatr to retrieve elevation raster.
#'  Defaults to 8.
#'
#' @return dataframe of substate geographies with elevation data
#'
#' @examples \dontrun{
#' elev_data <- get_elevation_data_batch(level = "county", state = "24") # All counties in Maryland
#' elev_data <- get_elevation_data_batch(level = "tract", state = "24") # All tracts in Maryland
#' elev_data <- get_elevation_data_batch(level = "tract", state = "24", county = "001") # Tracts in Allegany County, Maryland
#' }
#' @import dplyr
#' @import tidyr
#' @import tigris
#' @import raster
#' @import elevatr
#' @import data.table
#' @import sf
#' @import terra
#' @export
get_elevation_data_batch <- function(level, state, county = NULL, year = 2022, resolution = "500k", z = 8) {

  # Get state name from fips code
  stfips <- fread("https://gist.githubusercontent.com/marsha5813/14036adfbb6094f7fa3b25ee48299786/raw/75c53d82fc8998dc3f8dbd98f31e29fcbe50f1a3/stfips",colClasses = "character")
  stname <- stfips |> filter(fips == state) |> pull(stname)

  # Get state geometry polygon from tigris
  statepoly <- tigris::states(cb = TRUE,
                              resolution = resolution,
                              year = year)
  statepoly <- statepoly |> dplyr::filter(GEOID == state)

  # Get substate data
  if(level == "county"){

    # Get geometry polygons from tigris
    message(paste0("Getting geometries for all counties in ",stname," at a resolution of ",resolution))
    polies <- tigris::counties(cb = TRUE,
                               resolution = resolution,
                               year = year,
                               state = state)

    # Get centers of population from Census
    message("Getting point data for centers of population")
    popcenters <- fread("https://www2.census.gov/geo/docs/reference/cenpop2020/county/CenPop2020_Mean_CO.txt", colClasses = c("character","character","character","character","numeric","numeric","numeric"))
  }

  # If county is specified for tract-level request
  if(level == "tract" & length(county)>0){

    # Get geometry polygons from tigris
    message(paste0("Getting geometries for tracts in ",stname, ", in county fips: ",county, ", at a resolution of ", resolution))
    polies <- tigris::tracts(cb = TRUE,
                             resolution = resolution,
                             year = year,
                             state = state,
                             county = county)


    # Get centers of population from Census
    message("Getting point data for centers of population")
    popcenters <- fread("https://www2.census.gov/geo/docs/reference/cenpop2020/tract/CenPop2020_Mean_TR.txt", colClasses = c("character","character","character","numeric","numeric","numeric")) |>
      mutate(GEOID = paste0(STATEFP, COUNTYFP, TRACTCE)) |>
      filter(GEOID %in% polies$GEOID) |>
      dplyr::select(-GEOID)
  }

  # If no county is specified, assume whole state
  if(level == "tract" & length(county) == 0){
    message(paste0("Getting geometries for all tracts in ",stname," at a resolution of ",resolution))
    polies <- tigris::tracts(cb = TRUE,
                             resolution = resolution,
                             year = year,
                             state = state)

    # Get centers of population from Census
    message("Getting point data for centers of population")
    popcenters <- fread("https://www2.census.gov/geo/docs/reference/cenpop2020/tract/CenPop2020_Mean_TR.txt", colClasses = c("character","character","character","numeric","numeric","numeric"))
  }

  # Determine arc resolution
  zoom_level.df <- data.frame(
    z_level = seq(0,16,1),
    nominal = c(
      "1.5 arc degrees","40 arc minutes",
      "20 arc minutes","10 arc minutes",
      "5 arc minutes","2.5 arc minutes",
      "1 arc minutes","30 arc seconds",
      "15 arc seconds","7.5 arc seconds",
      "5 arc seconds","3 arc seconds",
      "1 arc seconds","2/3 arc seconds",
      "1/3 arc seconds","1/5 arc seconds",
      "1/9 arc seconds"
    )
  )
  res <- zoom_level.df |> filter(z_level == z) |> pull(nominal)

  # Pull raster elevation data for state
  message(paste("Getting raster data for",stname,"at a resolution of",res))
  stateraster <- elevatr::get_elev_raster(locations = statepoly, z = z, src = "aws")
  names(stateraster) <- "elevation"
  stateraster_terra <- rast(stateraster) # Convert to terra object

  # Get elevation for centers of population
  message(paste("Getting elevation at each",level,"center of population"))
  elev_popcenters <- popcenters |> filter(STATEFP == state)
  coordinates(elev_popcenters) <- ~LONGITUDE+LATITUDE
  proj4string(elev_popcenters) <- CRS("+proj=longlat +datum=NAD83 +no_defs")
  elev_popcenters$elevation_popcenter <- raster::extract(stateraster, elev_popcenters)
  elev_popcenters <- elev_popcenters |>
    as.data.frame() |>
    tidyr::unite(GEOID, ends_with("FP") | ends_with("CE"), sep = "") |>
    dplyr::select(GEOID, elevation_popcenter)

  # Get mean elevation for each subgeo
  message(paste("Getting mean elevation for each",level))
  polies_vect <- vect(polies) # Convert the sf object to a SpatVector
  elevation_mean <- terra::zonal(stateraster_terra, polies_vect, fun = "mean", na.rm = TRUE)
  names(elevation_mean) <- "elevation_mean"
  elevation_mean <- round(elevation_mean)
  elevation_mean_df <- cbind(polies,elevation_mean) |>
    as.data.frame()

  # Prepare output data
  message("Preparing final data")
  outdata <- elev_popcenters |>
    left_join(elevation_mean_df, by = "GEOID") |>
    dplyr::select(any_of(c("GEOID", "NAMELSAD", "NAMELSADCO", "STATE_NAME",
                           "elevation_popcenter", "elevation_mean")))

  message("Done")

  return(outdata)
}
