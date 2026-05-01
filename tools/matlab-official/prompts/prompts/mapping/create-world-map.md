---
title: Create World Map Visualization
description: Create world maps with geographic data using MATLAB Mapping Toolbox
tags: [matlab, mapping-toolbox, world-map, geographic-data, visualization, geoplot, projections]
release: R2023a+
notes: Requires Mapping Toolbox. Covers both newmap (R2023a+) and worldmap approaches.
---

# Create World Map Visualization

Create professional world maps with geographic data using MATLAB Mapping Toolbox, including projections, regions, and custom styling.

## Metadata

- **Tags:** `matlab` `mapping-toolbox` `world-map` `geographic-data` `visualization` `geoplot` `projections`
- **MATLAB Release:** R2023a+ (for newmap), any version (for worldmap)
- **Required Toolboxes:** Mapping Toolbox

## The Prompt

```text
Create a world map visualization in MATLAB using Mapping Toolbox:

Requirements:
1. Set up appropriate map projection for [REGION/PURPOSE]
2. Load and display geographic data (coastlines, boundaries, cities, etc.)
3. Add custom styling (colors, line styles, markers)
4. Include map elements (title, legend, scale, grid)
5. Handle multiple data layers
6. Add text labels for features
7. Export high-quality figure

Data sources: [SPECIFY: shapefiles/MAT files/geotables/custom data]
Map region: [SPECIFY: world/continent/country/custom bounds]
Projection preference: [SPECIFY: Equal Earth/Robinson/Mercator/custom]
Display features: [LIST: coastlines/borders/rivers/cities/custom]
Color scheme: [SPECIFY: default/custom/colorblind-friendly]
Output format: [SPECIFY: figure/image/PDF]

Use modern map axes approach (R2023a+) if available, otherwise use axesm-based approach.
```

## Usage Tips

1. **Specify your MATLAB version:** Determines whether to use newmap or worldmap
2. **Define the geographic scope:** World, continent, country, or custom region
3. **List required features:** Coastlines, political boundaries, cities, rivers, etc.
4. **Mention data format:** Shapefiles, MAT files, or custom coordinates
5. **Specify visualization purpose:** Thematic mapping, reference map, data overlay

## Example Usage

### Example 1: Basic World Map with Coastlines

```
Create a world map visualization in MATLAB using Mapping Toolbox:

Data sources: Built-in coastline data
Map region: World
Projection preference: Robinson (for global view)
Display features: Coastlines and major land masses
Color scheme: Blue ocean, green land
Output format: Figure window

Create a simple, clean world map suitable for presentations.
```

### Example 2: Regional Map with Multiple Layers

```
Create a world map visualization in MATLAB using Mapping Toolbox:

Data sources:
- europe_shapefile.shp for boundaries
- cities.mat for major cities
- rivers.shp for water features

Map region: Europe
Projection preference: Lambert Azimuthal Equal Area (EPSG:3035)
Display features:
- Country boundaries (black lines)
- Major cities (red markers with labels)
- Rivers (blue lines)
- Terrain background

Color scheme: Topographic with elevation coloring
Output format: High-resolution PNG (300 DPI)

Include legend, scale bar, and coordinate grid.
```

### Example 3: Thematic World Map with Data Overlay

```
Create a world map visualization in MATLAB using Mapping Toolbox:

Requirements:
- Display world countries with color-coded data values
- Add interactive tooltips for country information
- Include major cities as reference points

Data sources:
- World shapefile with country polygons
- CSV file with country statistics (GDP, population, etc.)
- Cities database with lat/lon coordinates

Map region: World (focused on populated areas)
Projection preference: Equal Earth (for accurate area representation)
Display features:
- Countries colored by data values
- Capital cities with sized markers
- Ocean and land boundaries

Color scheme: Sequential colormap (parula or viridis)
Output format: Interactive figure with data cursor

Add colorbar, legend, title with data source, and timestamp.
```

## Code Patterns

### Modern Approach (R2023a+)
```matlab
% Create map with newmap
figure
newmap  % Default Equal Earth projection

% Load and display data
land = readgeotable("landareas.shp");
rivers = readgeotable("rivers.shp");
cities = readgeotable("worldcities.shp");

% Plot features
geoplot(land, FaceColor=[0.65 0.85 0.45], EdgeColor="black")
hold on
geoplot(rivers, Color=[0 0.4470 0.7410], LineWidth=0.5)
geoplot(cities, MarkerSize=5, MarkerEdgeColor="red")

% Add labels
text(cities.Latitude, cities.Longitude, cities.Name, ...
     FontSize=8, HorizontalAlignment="left")

% Customize map
title("World Map")
```

### Traditional Approach (axesm-based)
```matlab
% Create world map
figure
worldmap world  % Automatic projection selection

% Load coastline data
load coastlines

% Plot coastlines
plotm(coastlat, coastlon, 'k-', 'LineWidth', 1)

% Add geographic features
geoshow('landareas.shp', 'FaceColor', [0.5 1.0 0.5])
geoshow('worldrivers.shp', 'Color', 'blue')

% Add cities
[lat, lon] = readvars('cities.csv');
plotm(lat, lon, 'r.', 'MarkerSize', 10)

% Customize
mlabel on  % Meridian labels
plabel on  % Parallel labels
gridm on   % Grid lines
```

### Custom Projection
```matlab
% Specify projection using projcrs
crs = projcrs(3035);  % EPSG:3035 for Europe
figure
newmap(crs)

% Or for axesm
figure
axesm('MapProjection', 'lambert', ...
      'MapLatLimit', [35 75], ...
      'MapLonLimit', [-15 40])
```

### Data Overlay on Map
```matlab
% Load country shapes and data
countries = readgeotable("countries.shp");
data = readtable("country_stats.csv");

% Join data with shapes
countries = join(countries, data, 'Keys', 'NAME');

% Create choropleth map
figure
newmap
geoplot(countries, ColorVariable="GDP", ...
        EdgeColor="black", LineWidth=0.5)
colorbar
colormap(parula)
title("World GDP by Country")
```

### Exporting Maps
```matlab
% High-quality export
print('worldmap', '-dpng', '-r300')  % 300 DPI PNG
exportgraphics(gcf, 'worldmap.pdf', 'ContentType', 'vector')
saveas(gcf, 'worldmap.fig')  % MATLAB figure format
```

## Common Customizations

### Map Projections
```matlab
% Common world projections
worldmap world          % Robinson (default for world)
worldmap('world', 'mercator')  % Mercator
worldmap('world', 'mollweide')  % Mollweide
worldmap('world', 'winkel')     % Winkel Tripel

% Regional projections
worldmap europe         % Equidistant Conic
worldmap('north america', 'lambert')  % Lambert Conformal
worldmap('antarctica', 'stereo')      % Stereographic
```

### Styling Options
```matlab
% Ocean and land colors
setm(gca, 'FFaceColor', [0.5 0.7 0.9])  % Ocean color
setm(gca, 'FEdgeColor', 'black')        % Coastline color

% Grid customization
setm(gca, 'Grid', 'on', ...
     'GLineStyle', ':', ...
     'GColor', [0.5 0.5 0.5])

% Frame and labels
setm(gca, 'Frame', 'on', ...
     'FLineWidth', 2, ...
     'MLabelLocation', 30, ...  % Every 30 degrees
     'PLabelLocation', 30)
```

### Interactive Features
```matlab
% Add data cursor for coordinates
dcm = datacursormode(gcf);
set(dcm, 'UpdateFcn', @(obj, event) ...
    sprintf('Lat: %.2f\nLon: %.2f', ...
    event.Position(2), event.Position(1)));

% Enable zoom and pan
zoom on
pan on
```

## References

- [MATLAB Documentation: Create a World Map](https://www.mathworks.com/help/map/create-a-world-map.html)
- [MATLAB Documentation: Choose a 2-D Map Display](https://www.mathworks.com/help/map/choose-a-2-d-map-display.html)
- [MATLAB Documentation: Mapping Toolbox Functions](https://www.mathworks.com/help/map/referencelist.html)
