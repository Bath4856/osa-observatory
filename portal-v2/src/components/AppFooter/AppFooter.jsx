import { Link } from 'react-router-dom'
import { useLang } from '../../i18n/useLang'
import './AppFooter.css'

export default function AppFooter() {
  const { t } = useLang()

  return (
    <footer className="app-footer">
      <div className="footer-col footer-brand">
        <span className="footer-logo">OSA Observatory</span>
        <span className="footer-tagline">Measuring African Sovereignty</span>
        <span className="footer-license">CC-BY-NC-4.0</span>
      </div>
      <nav className="footer-col footer-nav">
        <Link to="/countries">{t('nav.countries')}</Link>
        <Link to="/about">{t('nav.about')}</Link>
        <Link to="/methodology">{t('nav.methodology')}</Link>
        <Link to="/participate">{t('nav.participate')}</Link>
        <Link to="/data">{t('nav.data')}</Link>
      </nav>
      <div className="footer-col footer-links">
        <a href="https://api.osa-observatory.africa/docs" target="_blank" rel="noreferrer">
          {t('footer.api')} →
        </a>
        <Link to="/participate">{t('footer.contact')} →</Link>
        <span className="footer-copy">© OSA Observatory 2026</span>
      </div>
    </footer>
  )
}
