import { Link } from 'react-router-dom'
import { useLang } from '../i18n/useLang'
import './Countries.css'

const COUNTRIES = [
  {iso3:'DZA',name:{en:'Algeria',fr:'Algerie'},region:'North Africa'},
  {iso3:'AGO',name:{en:'Angola',fr:'Angola'},region:'Central Africa'},
  {iso3:'BEN',name:{en:'Benin',fr:'Benin'},region:'West Africa'},
  {iso3:'BWA',name:{en:'Botswana',fr:'Botswana'},region:'Southern Africa'},
  {iso3:'BFA',name:{en:'Burkina Faso',fr:'Burkina Faso'},region:'West Africa'},
  {iso3:'BDI',name:{en:'Burundi',fr:'Burundi'},region:'East Africa'},
  {iso3:'CPV',name:{en:'Cabo Verde',fr:'Cap-Vert'},region:'West Africa'},
  {iso3:'CMR',name:{en:'Cameroon',fr:'Cameroun'},region:'Central Africa'},
  {iso3:'CAF',name:{en:'Central African Republic',fr:'Centrafrique'},region:'Central Africa'},
  {iso3:'TCD',name:{en:'Chad',fr:'Tchad'},region:'Central Africa'},
  {iso3:'COM',name:{en:'Comoros',fr:'Comores'},region:'East Africa'},
  {iso3:'COD',name:{en:'DR Congo',fr:'RD Congo'},region:'Central Africa'},
  {iso3:'COG',name:{en:'Republic of Congo',fr:'Congo'},region:'Central Africa'},
  {iso3:'CIV',name:{en:"Cote d'Ivoire",fr:"Cote d'Ivoire"},region:'West Africa'},
  {iso3:'DJI',name:{en:'Djibouti',fr:'Djibouti'},region:'East Africa'},
  {iso3:'EGY',name:{en:'Egypt',fr:'Egypte'},region:'North Africa'},
  {iso3:'GNQ',name:{en:'Equatorial Guinea',fr:'Guinee equatoriale'},region:'Central Africa'},
  {iso3:'ERI',name:{en:'Eritrea',fr:'Erythree'},region:'East Africa'},
  {iso3:'SWZ',name:{en:'Eswatini',fr:'Eswatini'},region:'Southern Africa'},
  {iso3:'ETH',name:{en:'Ethiopia',fr:'Ethiopie'},region:'East Africa'},
  {iso3:'GAB',name:{en:'Gabon',fr:'Gabon'},region:'Central Africa'},
  {iso3:'GMB',name:{en:'Gambia',fr:'Gambie'},region:'West Africa'},
  {iso3:'GHA',name:{en:'Ghana',fr:'Ghana'},region:'West Africa'},
  {iso3:'GIN',name:{en:'Guinea',fr:'Guinee'},region:'West Africa'},
  {iso3:'GNB',name:{en:'Guinea-Bissau',fr:'Guinee-Bissau'},region:'West Africa'},
  {iso3:'KEN',name:{en:'Kenya',fr:'Kenya'},region:'East Africa'},
  {iso3:'LSO',name:{en:'Lesotho',fr:'Lesotho'},region:'Southern Africa'},
  {iso3:'LBR',name:{en:'Liberia',fr:'Liberia'},region:'West Africa'},
  {iso3:'LBY',name:{en:'Libya',fr:'Libye'},region:'North Africa'},
  {iso3:'MDG',name:{en:'Madagascar',fr:'Madagascar'},region:'East Africa'},
  {iso3:'MWI',name:{en:'Malawi',fr:'Malawi'},region:'East Africa'},
  {iso3:'MLI',name:{en:'Mali',fr:'Mali'},region:'West Africa'},
  {iso3:'MRT',name:{en:'Mauritania',fr:'Mauritanie'},region:'West Africa'},
  {iso3:'MUS',name:{en:'Mauritius',fr:'Maurice'},region:'East Africa'},
  {iso3:'MAR',name:{en:'Morocco',fr:'Maroc'},region:'North Africa'},
  {iso3:'MOZ',name:{en:'Mozambique',fr:'Mozambique'},region:'East Africa'},
  {iso3:'NAM',name:{en:'Namibia',fr:'Namibie'},region:'Southern Africa'},
  {iso3:'NER',name:{en:'Niger',fr:'Niger'},region:'West Africa'},
  {iso3:'NGA',name:{en:'Nigeria',fr:'Nigeria'},region:'West Africa'},
  {iso3:'RWA',name:{en:'Rwanda',fr:'Rwanda'},region:'East Africa'},
  {iso3:'STP',name:{en:'Sao Tome and Principe',fr:'Sao Tome-et-Principe'},region:'Central Africa'},
  {iso3:'SEN',name:{en:'Senegal',fr:'Senegal'},region:'West Africa'},
  {iso3:'SLE',name:{en:'Sierra Leone',fr:'Sierra Leone'},region:'West Africa'},
  {iso3:'SOM',name:{en:'Somalia',fr:'Somalie'},region:'East Africa'},
  {iso3:'ZAF',name:{en:'South Africa',fr:'Afrique du Sud'},region:'Southern Africa'},
  {iso3:'SSD',name:{en:'South Sudan',fr:'Soudan du Sud'},region:'East Africa'},
  {iso3:'SDN',name:{en:'Sudan',fr:'Soudan'},region:'North Africa'},
  {iso3:'TZA',name:{en:'Tanzania',fr:'Tanzanie'},region:'East Africa'},
  {iso3:'TGO',name:{en:'Togo',fr:'Togo'},region:'West Africa'},
  {iso3:'TUN',name:{en:'Tunisia',fr:'Tunisie'},region:'North Africa'},
  {iso3:'UGA',name:{en:'Uganda',fr:'Ouganda'},region:'East Africa'},
  {iso3:'ZMB',name:{en:'Zambia',fr:'Zambie'},region:'Southern Africa'},
  {iso3:'ZWE',name:{en:'Zimbabwe',fr:'Zimbabwe'},region:'Southern Africa'},
  {iso3:'SYC',name:{en:'Seychelles',fr:'Seychelles'},region:'East Africa'},
]

const REGIONS = ['All','North Africa','West Africa','Central Africa','East Africa','Southern Africa']

export default function Countries() {
  const { lang } = useLang()
  const [filter, setFilter] = useState('All')
  const [search, setSearch] = useState('')

  const filtered = COUNTRIES.filter(c => {
    const matchRegion = filter === 'All' || c.region === filter
    const matchSearch = c.name[lang].toLowerCase().includes(search.toLowerCase()) ||
                        c.iso3.toLowerCase().includes(search.toLowerCase())
    return matchRegion && matchSearch
  }).sort((a,b) => a.name[lang].localeCompare(b.name[lang]))

  return (
    <div className="countries-page">
      <h1 className="countries-title">54 African Countries</h1>
      <div className="countries-filters">
        <input
          className="search-input"
          placeholder="Search..."
          value={search}
          onChange={e => setSearch(e.target.value)} />
        <div className="region-filters">
          {REGIONS.map(r => (
            <button key={r}
              className={`region-btn ${filter === r ? 'active' : ''}`}
              onClick={() => setFilter(r)}>{r}</button>
          ))}
        </div>
      </div>
      <div className="countries-grid">
        {filtered.map(c => (
          <Link key={c.iso3} to={`/country/${c.iso3}`} className="country-card">
            <span className="card-iso">{c.iso3}</span>
            <span className="card-name">{c.name[lang]}</span>
            <span className="card-region">{c.region}</span>
          </Link>
        ))}
      </div>
    </div>
  )
}
