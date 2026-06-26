import { Link, useLocation } from 'react-router-dom'
import { useLang } from '../../i18n/useLang'
import './AppHeader.css'

const AFRICA_PATH = "M337.5,295.5 L359.1,303.4 L371.5,328.7 L370.2,340.3 L317.1,366.1 L321.9,334.8 L313.7,298.1 L337.5,295.5 Z M314.9,294.2 L314.9,294.2 Z M413.3,286.7 L417.8,284.1 L413.3,286.7 Z M258.1,218 L250.9,184.3 L261.2,197.7 L258.1,218 Z M226,196.5 L216.7,178 L240.9,162.8 L249.7,187.1 L226,196.5 Z M391.8,376.2 L400.4,408.4 L375.4,420.7 L364.1,397.2 L391.8,376.2 Z M331.4,210.6 L359.3,200.5 L381.1,202.7 L396.2,225.1 L368.6,231 L335.7,243.5 L328.5,217.1 L331.4,210.6 Z M318.6,243.5 L291.9,229.3 L312.7,208.2 L325,178.3 L323.7,197 L326.8,227.8 L318.6,243.5 Z M422,235.6 L413,268.3 L421.5,311.2 L414.9,335.7 L386.8,329.7 L369.4,314.8 L353.2,308.9 L316.6,296 L325.2,288.6 L345.3,258.3 L360.6,228 L389.7,225 L416.9,231.3 L422,235.6 Z M318.1,288.5 L318.8,273.5 L318.6,243.5 L347.8,242.9 L335.7,280.5 L318.1,288.5 Z M493.3,177 L485,183.8 L493.3,177 Z M312.3,108.2 L213.8,98.6 L221.2,56.1 L241.7,29 L290.3,25.5 L299.9,73.2 L309.8,104.2 L312.3,108.2 Z M445.8,69.8 L436.6,81.2 L411.4,117.6 L408.1,60 L442,58.8 L445.8,69.8 Z M489.1,178 L461.4,167.3 L474.3,159.5 L489.1,178 Z M463.2,162.5 L487,180.8 L496.8,199.4 L474.5,233.5 L448,222.8 L441.9,190.2 L463.2,162.5 Z M307.1,283.4 L308.1,243.5 L325.8,261.5 L307.1,283.4 Z M248.6,220.1 L225.2,191.7 L246.6,204.9 L248.6,220.1 Z M193.3,208.9 L181.4,202.4 L165.3,201.2 L160.3,183.5 L174.6,178.9 L188.2,179.3 L195.7,192.9 L193.3,208.9 Z M144.4,174.1 L156.8,173.1 L144.4,174.1 Z M297.7,251.5 L297.7,251.5 Z M481.2,263.5 L462,277.7 L444,227.1 L472.8,236.1 L481.2,263.5 Z M197.6,230.1 L184.2,204.2 L192.4,216.7 L197.6,230.1 Z M328.9,112.1 L299,88.8 L304.4,55.3 L347.4,61.7 L379.9,52.6 L388,130.4 L328.9,112.1 Z M411.2,442.7 L408.7,440.7 L411.2,442.7 Z M212.2,29.9 L227.2,53.2 L191.1,81.5 L169.7,99.9 L147.4,111.1 L169,79.1 L202.2,40.3 L212.2,29.9 Z M530.9,337.5 L532.3,365.6 L503.5,419.7 L501.4,382 L515.4,355 L530.9,337.5 Z M171.6,164.7 L210.5,153.8 L267.3,135.8 L236.3,162.4 L212.2,185.4 L196.5,192.3 L189.3,179.4 L175.4,178.6 L171.6,164.7 Z M443.7,331.5 L477.9,333 L451.5,378.2 L449.8,409.2 L428.7,425.7 L432.4,381.9 L418.2,352.4 L450.8,359.4 L443.7,331.5 Z M171.6,164.7 L147.7,148.4 L167.5,109.4 L210.2,159.1 L171.6,164.7 Z M443.7,331.5 L442.2,356.7 L436.5,326.9 L443.7,331.5 Z M337.6,440.3 L317.2,383.5 L352.8,371.5 L377.5,372 L343.7,441.6 L337.6,440.3 Z M255,181.8 L263.7,158.6 L330.4,122 L323.7,172.8 L306.5,172.6 L267.9,170.3 L255,181.8 Z M292,227.5 L258.5,207.8 L265.6,175.3 L301.4,173.3 L326.7,182 L310.9,213.4 L292,227.5 Z M419.6,265.2 L414.7,266.5 L419.6,265.2 Z M440.2,197.6 L430.6,183.4 L405.3,198 L383.3,202.3 L373.5,183.5 L376.5,157.9 L457.7,125 L454.6,166 L440.2,197.6 Z M440.2,197.6 L444,227.1 L409.6,229.6 L385.5,205.5 L400.3,196.5 L427.9,190.8 L439.5,194.3 L440.2,197.6 Z M145.2,171.2 L160.4,154 L171.4,178.4 L149.7,174.2 L154.7,169.4 L145.2,171.2 Z M175.9,214.7 L173.1,193.9 L177.3,212.6 L175.9,214.7 Z M532,184.1 L530.4,214.6 L481.2,263.5 L527.4,194.3 L532,184.1 Z M326.9,175.9 L332.6,125.7 L372.3,166.6 L375.6,186.9 L339.7,210.1 L325,194 L326.9,175.9 Z M253.3,218.8 L242.6,187.7 L253.3,218.8 Z M297.7,64.6 L297.8,19.7 L302.7,42.4 L297.7,64.6 Z M439.9,264 L471,309.1 L455.1,332.8 L421.5,311.2 L421.5,277.3 L439.9,264 Z M428,264.5 L422.1,246.2 L443.9,238.5 L428,264.5 Z M426,444.6 L392.6,474.5 L354.2,477.8 L341.8,448.6 L358.3,416 L380.7,420 L413.8,398.9 L423.2,422.1 L430,441.4 L426,444.6 Z M433.2,316.9 L418.7,356.9 L388.5,370.7 L382.7,335.8 L400.6,332 L408.4,326.8 L433.2,316.9 Z M424.1,399.9 L394.8,381.1 L411,360.3 L432.6,377.1 L424.1,399.9 Z"

const LogoMark = () => (
  <svg width="38" height="38" viewBox="130 10 460 510" xmlns="http://www.w3.org/2000/svg" style={{flexShrink:0}}>
    <path d={AFRICA_PATH} fill="#1A6B2A" stroke="#C8973A" strokeWidth="4"/>
    <circle cx="340" cy="260" r="12" fill="#C8973A" opacity="0.9"/>
  </svg>
)

export default function AppHeader() {
  const { lang, t, switchLang } = useLang()
  const location = useLocation()
  const isActive = (path) => location.pathname === path ? 'active' : ''
  const isHome = location.pathname === '/'

  return (
    <header className="app-header">
      <div className="header-left">
        <Link to="/" className="header-logo" title={t('nav.home')}>
          <LogoMark />
          <div className="logo-text">
            <span className="logo-osa">OSA</span>
            <span className="logo-tagline">Observatory</span>
          </div>
          {!isHome && <span className="home-icon" title={t('nav.home')}>⌂</span>}
        </Link>
      </div>
      <nav className="header-nav">
        <Link to="/countries" className={isActive('/countries')}>{t('nav.countries')}</Link>
        <Link to="/about" className={isActive('/about')}>{t('nav.about')}</Link>
        <Link to="/pillars" className={isActive('/pillars')}>{lang === 'fr' ? 'Piliers' : 'Pillars'}</Link>
        <Link to="/methodology" className={isActive('/methodology')}>{t('nav.methodology')}</Link>
        <Link to="/data" className={isActive('/data')}>{t('nav.data')}</Link>
        <Link to="/participate" className={isActive('/participate')}>{t('nav.participate')}</Link>
      </nav>
      <div className="header-right">
        <button className={`lang-btn ${lang==='en'?'active':''}`}
          onClick={() => switchLang('en')}>EN</button>
        <span className="lang-sep">|</span>
        <button className={`lang-btn ${lang==='fr'?'active':''}`}
          onClick={() => switchLang('fr')}>FR</button>
      </div>
    </header>
  )
}
