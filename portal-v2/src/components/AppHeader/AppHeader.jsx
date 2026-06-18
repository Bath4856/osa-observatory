import { Link, useLocation } from 'react-router-dom'
import { useLang } from '../../i18n/useLang'
import './AppHeader.css'

export default function AppHeader() {
  const { lang, t, switchLang } = useLang()
  const location = useLocation()

  const isActive = (path) => location.pathname === path ? 'active' : ''

  return (
    <header className="app-header">
      <div className="header-left">
        <Link to="/" className="header-logo">
          <span className="logo-osa">OSA</span>
          <span className="logo-tagline">Observatory</span>
        </Link>
      </div>
      <nav className="header-nav">
        <Link to="/countries" className={isActive('/countries')}>{t('nav.countries')}</Link>
        <Link to="/about" className={isActive('/about')}>{t('nav.about')}</Link>
        <Link to="/methodology" className={isActive('/methodology')}>{t('nav.methodology')}</Link>
        <Link to="/data" className={isActive('/data')}>{t('nav.data')}</Link>
        <Link to="/participate" className={isActive('/participate')}>{t('nav.participate')}</Link>
      </nav>
      <div className="header-right">
        <button
          className={`lang-btn ${lang === 'en' ? 'active' : ''}`}
          onClick={() => switchLang('en')}>EN</button>
        <span className="lang-sep">|</span>
        <button
          className={`lang-btn ${lang === 'fr' ? 'active' : ''}`}
          onClick={() => switchLang('fr')}>FR</button>
      </div>
    </header>
  )
}
