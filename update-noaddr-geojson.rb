require 'httparty'

class BuildingsDownloader
  def download
    File.write('ulsk_buildings_no_addr.geojson', sorted_buildings_geojson)
  end

  private

  def overpass_query(query)
    i 'Querying Overpass API...'
    HTTParty.post('http://overpass-api.de/api/interpreter', body: query)
  end

  def overpass_data
    overpass_query <<-OverpassQL
      [out:json];
      (way(54.24, 48.26, 54.37, 48.42);) -> .all;
      (way.all["building"]; - way.all["addr:housenumber"];);
      (._; >>;);
      out skel;
    OverpassQL
  end

  def buildings
    corners   = {}
    buildings = {}

    overpass_data['elements'].each do |element|
      i "Processing element #{element['id']}..."

      case element['type']
        when 'node'
          corners[element['id']] = [element['lon'], element['lat']]
        when 'way'
          buildings[element['id']] = element['nodes'].map { |id| corners[id] }
      end
    end

    buildings
  end

  def sorted_buildings
    i "Sorting #{buildings.size} buildings by area..."
    buildings.sort_by { |_, building| building_area(building) }.reverse
  end

  def building_area(corners)
    lats = []
    lons = []

    corners.each do |lat, lon|
      lats.push(lat)
      lons.push(lon)
    end

    y = lats.max - lats.min
    x = lons.max - lons.min

    x * y
  end

  def features
    i 'Converting buildings to GeoJSON...'

    # TODO If a feature has a commonly used identifier, that identifier should be included as a member of the feature object with the name "id".
    sorted_buildings.map do |id, building|
      {
        type: 'Feature',
        geometry:   {
          type:        'Polygon',
          coordinates: [
            building
          ]
        },
        properties: {
          id: id
        }
      }
    end
  end

  def sorted_buildings_geojson
    {type: 'FeatureCollection', features: features}.to_json(indent: '   ', space: ' ', object_nl: "\n", array_nl: "\n")
  end

  def i(message)
    puts message
  end
end

BuildingsDownloader.new.download
