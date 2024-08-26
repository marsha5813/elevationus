#' Retrieve elevation data for US geographies
#'
#' @param level Character. One of "state", "county" or "tract"
#' @param geoid Character. The FIPS code of your geography.
#'  Two digits for state, five for county, eleven for tract.
#' @param year Numeric. Year for the geographic boundaries.
#'  Defaults to 2022.
#' @param resolution Character. Resolution for the cartographic
#'  boundary file retrieved by tigris::. Defaults to "500K". Other options are "5m" (1:5 million) and "20m" (1:20  million).
#' @param z Resolution used by elevatr to retrieve elevation raster.
#'  Defaults to 8.
#'
#' @return List containing: "map"
#'  (a map of your geography showing elevation);
#'  "elevation_mean" (elevation of your geography);
#'  "raster" (raster file returned by elevatr and
#'  cropped to your geographic polygon);
#'  and "elevation.df" (elevation data in a dataframe with
#'  coordinates in 'x' and 'y' columns).
#'
#' @examples \dontrun{
#' elev <- get_elevation_data(level = "state", geoid = "41")
#' print(paste("Mean elevation:",elev$elevation_mean,"meters"))
#' elev$map
#'
#' elev <- get_elevation_data(level = "county", geoid = "24021", z = 10)
#' print(paste("Mean elevation:",elev$elevation_mean,"meters"))
#' elev$map
#'
#' elev <- get_elevation_data(level = "tract", geoid = "24510200100", z = 8)
#' print(paste("Mean elevation:",elev$elevation_mean,"meters"))
#' elev$map
#' }
#' @export
get_elevation_data <- function(level, geoid, year = 2022, resolution = "500k", z = 8) {

  # Pull polygon geometry
  if(level == "state"){
    poly <- tigris::states(cb = TRUE,
                           resolution = resolution,
                           year = year)

    poly <- poly |> dplyr::filter(GEOID == geoid)
    geoname <- poly$NAME
  }

  if(level == "county"){
    poly <- tigris::counties(cb = TRUE,
                             resolution = resolution,
                             year = year,
                             state = substr(geoid,1,2))
    poly <- poly |> dplyr::filter(GEOID == geoid)
    geoname <- paste0(poly$NAMELSAD, ", ", poly$STATE_NAME)
  }

  if(level == "tract"){
    poly <- tigris::tracts(cb = TRUE,
                           resolution = resolution,
                           year = year,
                           state = substr(geoid,1,2),
                           county = substr(geoid,3,5))
    poly <- poly |> dplyr::filter(GEOID == geoid)
    geoname <- paste0(poly$NAMELSAD, ", ", poly$NAMELSADCO, ", ", poly$STATE_NAME)
  }

  # Pull raster elevation data
  raster_data <- elevatr::get_elev_raster(locations = poly, z = z, src = "aws")

  # Crop raster and convert to dataframe
  raster_cropped <- raster::mask(raster_data, poly)
  elev.df <- raster::as.data.frame(raster_cropped, xy = T)
  names(elev.df) <- c("x", "y", "elevation")
  elev.df <- elev.df |> dplyr::filter(!is.na(elevation))

  # Create a map
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
  zoom_level <- zoom_level.df |> dplyr::filter(z_level == z) |> dplyr::pull(nominal)

  g <- ggplot2::ggplot() +
    geom_raster(data = elev.df, aes(x, y, fill = elevation)) +
    geom_sf(data = poly, fill = NA, color = "white") +
    labs(fill = "Elevation (m)",
         title = geoname,
         subtitle = paste0("Arc resolution: ", zoom_level)) +
    theme_void()

  # Create output objects
  out <- list(elevation_data = elev.df,
              elevation_mean = mean(elev.df$elevation),
              raster = raster_cropped,
              map = g)

  return(out)
}
