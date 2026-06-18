import { useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import * as d3 from 'd3'
import { useLang } from '../../i18n/useLang'
import './CountryMap.css'

const AFRICA_ISO3 = [
  'DZA','AGO','BEN','BWA','BFA','BDI','CPV','CMR','CAF','TCD',
  'COM','COD','COG','CIV','DJI','EGY','GNQ','ERI','SWZ','ETH',
  'GAB','GMB','GHA','GIN','GNB','KEN','LSO','LBR','LBY','MDG',
  'MWI','MLI','MRT','MUS','MAR','MOZ','NAM','NER','NGA','RWA',
  'STP','SEN','SLE','SOM','ZAF','SSD','SDN','TZA','TGO','TUN',
  'UGA','ZMB','ZWE','SYC'
]

export default function CountryMap({ scoresData }) {
  const svgRef = useRef(null)
  const navigate = useNavigate()
  const { lang } = useLang()
  const [tooltip, setTooltip] = useState(null)
  const [geoData, setGeoData] = useState(null)

  useEffect(() => {
    fetch('/africa.geojson')
      .then(r => r.json())
      .then(world => {
        const africa = {
          ...world,
          features: world.features.filter(f =>
            AFRICA_ISO3.includes(f.properties.adm0_iso || f.properties.iso_a3 || f.properties.ISO_A3)
          )
        }
        setGeoData(africa)
      })
      .catch(() => {
        fetch('/src/assets/africa.geojson')
          .then(r => r.json())
          .then(world => {
            const africa = {
              ...world,
              features: world.features.filter(f =>
                AFRICA_ISO3.includes(f.properties.iso_a3 || f.properties.ISO_A3)
              )
            }
            setGeoData(africa)
          })
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
      const entry = scoresData.find(d => d.iso3 === iso3 && d.year === 2024)
      return entry ? (entry.isa_score ?? entry.score) : null
    }

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
        const iso3 = d.properties.iso_a3 || d.properties.ISO_A3
        const name = d.properties.name || iso3
        const isa = getISA(iso3)
        d3.select(this).attr('fill', '#1F4E5F')
        const [mx, my] = d3.pointer(event, svgRef.current.parentNode)
        setTooltip({ iso3, name, isa, x: mx, y: my })
      })
      .on('mouseleave', function() {
        d3.select(this).attr('fill', '#2E7D6E')
        setTooltip(null)
      })
      .on('click', function(event, d) {
        const iso3 = d.properties.iso_a3 || d.properties.ISO_A3
        if (AFRICA_ISO3.includes(iso3)) navigate(`/country/${iso3}`)
      })
  }, [geoData, scoresData, navigate])

  return (
    <div className="map-container">
      <svg ref={svgRef} className="africa-map" />
      {tooltip && (
        <div
          className="map-tooltip"
          style={{ left: tooltip.x + 12, top: tooltip.y - 10 }}>
          <div className="tooltip-name">{tooltip.name}</div>
          <div className="tooltip-iso">{tooltip.iso3}</div>
          {tooltip.isa !== null && tooltip.isa !== undefined && (
            <div className="tooltip-isa">ISA 2024 : <strong>{Number(tooltip.isa).toFixed(2)}</strong></div>
          )}
          <div className="tooltip-cta">View →</div>
        </div>
      )}
    </div>
  )
}
