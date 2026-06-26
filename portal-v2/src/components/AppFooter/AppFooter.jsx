import { Link } from 'react-router-dom'
import { useLang } from '../../i18n/useLang'
import logoHeader from '../../assets/logo_header.png'
import './AppFooter.css'

export default function AppFooter() {
  const { lang } = useLang()

  return (
    <footer className="app-footer">

      {/* Colonne 1 — Brand */}
      <div className="footer-brand">
        <div className="footer-brand-top">
          <img src={logoHeader} alt="OSA Observatory" className="footer-logo-img" />
          <span className="footer-logo-text">OSA Observatory</span>
        </div>
        <p className="footer-mission">
          {lang === 'fr'
            ? "Mesurer \u2022 Comprendre \u2022 Aider \u00e0 renforcer la souverainet\u00e9 des \u00c9tats africains."
            : "Measure \u2022 Understand \u2022 Help strengthen the sovereignty of African states."}
        </p>
        <span className="footer-license">CC-BY-NC-4.0</span>
      </div>

      {/* Colonne 2 — Explorer */}
      <div className="footer-col">
        <span className="footer-col-title">{lang === 'fr' ? 'Explorer' : 'Explore'}</span>
        <nav className="footer-nav">
          <Link to="/countries">{lang === 'fr' ? 'États' : 'Countries'}</Link>
          <Link to="/pillars">{lang === 'fr' ? 'Piliers' : 'Pillars'}</Link>
          <Link to="/methodology">{lang === 'fr' ? 'Méthodologie' : 'Methodology'}</Link>
          <Link to="/data">{lang === 'fr' ? 'Données ouvertes' : 'Open Data'}</Link>
          <Link to="/participate">E-Participation</Link>
          <Link to="/about">{lang === 'fr' ? 'À propos' : 'About'}</Link>
        </nav>
      </div>

      {/* Colonne 3 — Produits + liens */}
      <div className="footer-col footer-col-right">
        <span className="footer-col-title">{lang === 'fr' ? 'Produits' : 'Products'}</span>
        <nav className="footer-nav">
          <span className="footer-product">ISA</span>
          <span className="footer-product">IOSA</span>
          <span className="footer-product">GENECO</span>
          <span className="footer-product">AMAR</span>
        </nav>
        <div className="footer-links">
          <a href="https://api.osa-observatory.africa/docs" target="_blank" rel="noreferrer">
            API Explorer →
          </a>
          <Link to="/participate">Contact →</Link>
        </div>
        <div className="footer-copy">
          <span>© OSA Observatory 2026</span>
        </div>
      </div>

    </footer>
  )
}
