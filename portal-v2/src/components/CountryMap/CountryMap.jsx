import { useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import * as d3 from 'd3'
import './CountryMap.css'

const NAME_TO_ISO3 = {
  'Algeria':'DZA','Angola':'AGO','Benin':'BEN','Botswana':'BWA',
  'Burkina Faso':'BFA','Burundi':'BDI','Cabo Verde':'CPV','Cape Verde':'CPV',
  'Cameroon':'CMR','Central African Republic':'CAF','Chad':'TCD',
  'Comoros':'COM','Democratic Republic of the Congo':'COD',
  'Republic of the Congo':'COG',"Cote d'Ivoire":'CIV',"Côte d'Ivoire":'CIV',
  'Ivory Coast':'CIV','Djibouti':'DJI','Egypt':'EGY',
  'Equatorial Guinea':'GNQ','Eritrea':'ERI','Eswatini':'SWZ','Swaziland':'SWZ',
  'Ethiopia':'ETH','Gabon':'GAB','Gambia':'GMB','The Gambia':'GMB',
  'Ghana':'GHA','Guinea':'GIN','Guinea-Bissau':'GNB','Kenya':'KEN',
  'Lesotho':'LSO','Liberia':'LBR','Libya':'LBY','Madagascar':'MDG',
  'Malawi':'MWI','Mali':'MLI','Mauritania':'MRT','Mauritius':'MUS',
  'Morocco':'MAR','Mozambique':'MOZ','Namibia':'NAM','Niger':'NER',
  'Nigeria':'NGA','Rwanda':'RWA','Sao Tome and Principe':'STP',
  'São Tomé and Príncipe':'STP','Senegal':'SEN','Sierra Leone':'SLE',
  'Somalia':'SOM','South Africa':'ZAF','South Sudan':'SSD','Sudan':'SDN',
  'Tanzania':'TZA','United Republic of Tanzania':'TZA','Togo':'TGO',
  'Tunisia':'TUN','Uganda':'UGA','Zambia':'ZMB','Zimbabwe':'ZWE',
  'Seychelles':'SYC',
}

// Coordonnees des petites iles absentes du GeoJSON
const ISLAND_MARKERS = [
  { iso3:'STP', name:'Sao Tome and Principe', lon: 6.6131,  lat:  0.1864 },
  { iso3:'CPV', name:'Cabo Verde',            lon:-23.6051, lat: 14.9318 },
  { iso3:'COM', name:'Comoros',               lon: 43.3333, lat:-11.6455 },
  { iso3:'MUS', name:'Mauritius',             lon: 57.5522, lat:-20.2833 },
  { iso3:'SYC', name:'Seychelles',            lon: 55.4920, lat: -4.6796 },
]

export default function CountryMap({ scoresData }) {
  const svgRef = useRef(null)
  const navigate = useNavigate()
  const [tooltip, setTooltip] = useState(null)
  const [geoData, setGeoData] = useState(null)

  useEffect(() => {
    fetch('/africa.geojson')
      .then(r => r.json())
      .then(world => {
        const africa = {
          ...world,
          features: world.features.filter(f =>
            NAME_TO_ISO3[f.properties.name] !== undefined
          )
        }
        setGeoData(africa)
      })
  }, [])

  useEffect(() => {
    if (!geoData || !svgRef.current) return

    const svg = d3.select(svgRef.current)
    svg.selectAll('*').remove()

    const width = 500
    const height = 560

    svg.attr('viewBox', `0 0 ${width} ${height}`)

    const projection = d3.geoMercator()
      .fitSize([width, height], geoData)

    const path = d3.geoPath().projection(projection)

    const getISA = (iso3) => {
      if (!scoresData) return null
      const entry = scoresData.find(d => d.country_iso3 === iso3 && d.year === 2024)
      return entry ? (entry.isa_observed_score ?? entry.score) : null
    }

    const showTooltip = (event, iso3, name) => {
      const isa = getISA(iso3)
      const [mx, my] = d3.pointer(event, svgRef.current.parentNode)
      setTooltip({ iso3, name, isa, x: mx, y: my })
    }

    // Polygones continentaux
    svg.selectAll('path')
      .data(geoData.features)
      .enter()
      .append('path')
      .attr('d', path)
      .attr('class', 'country-path')
      .attr('fill', '#2E7D6E')
      .attr('stroke', '#ffffff')
      .attr('stroke-width', 0.5)
      .on('mouseenter', function(event, d) {
        const iso3 = NAME_TO_ISO3[d.properties.name]
        d3.select(this).attr('fill', '#1F4E5F')
        showTooltip(event, iso3, d.properties.name)
      })
      .on('mouseleave', function() {
        d3.select(this).attr('fill', '#2E7D6E')
        setTooltip(null)
      })
      .on('click', function(event, d) {
        const iso3 = NAME_TO_ISO3[d.properties.name]
        if (iso3) navigate(`/country/${iso3}`)
      })

    // Marqueurs circulaires pour les petites iles
    const islandGroup = svg.append('g').attr('class', 'island-markers')

    ISLAND_MARKERS.forEach(island => {
      const coords = projection([island.lon, island.lat])
      if (!coords) return

      const g = islandGroup.append('g')
        .attr('cursor', 'pointer')
        .on('mouseenter', function(event) {
          d3.select(this).select('circle').attr('fill', '#1F4E5F')
          showTooltip(event, island.iso3, island.name)
        })
        .on('mouseleave', function() {
          d3.select(this).select('circle').attr('fill', '#2E7D6E')
          setTooltip(null)
        })
        .on('click', () => navigate(`/country/${island.iso3}`))

      g.append('circle')
        .attr('cx', coords[0])
        .attr('cy', coords[1])
        .attr('r', 5)
        .attr('fill', '#2E7D6E')
        .attr('stroke', '#ffffff')
        .attr('stroke-width', 1.5)

      g.append('text')
        .attr('x', coords[0] + 7)
        .attr('y', coords[1] + 4)
        .attr('font-size', '7px')
        .attr('fill', '#1F4E5F')
        .attr('font-weight', '600')
        .text(island.iso3)
    })

  }, [geoData, scoresData, navigate])

  return (
    <div className="map-container">
      <svg ref={svgRef} className="africa-map" />
      {tooltip && (
        <div className="map-tooltip"
          style={{ left: tooltip.x + 12, top: tooltip.y - 10 }}>
          <div className="tooltip-name">{tooltip.name}</div>
          <div className="tooltip-iso">{tooltip.iso3}</div>
          {tooltip.isa != null && (
            <div className="tooltip-isa">ISA 2024 : <strong>{Number(tooltip.isa).toFixed(3)}</strong></div>
          )}
          <div className="tooltip-cta">View →</div>
        </div>
      )}
    </div>
  )
}
