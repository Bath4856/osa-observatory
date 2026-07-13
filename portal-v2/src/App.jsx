import { createBrowserRouter, RouterProvider, Outlet } from 'react-router-dom'
import AppHeader from './components/AppHeader/AppHeader'
import AppFooter from './components/AppFooter/AppFooter'
import Home from './pages/Home'
import Countries from './pages/Countries'
import Country from './pages/Country'
import CountryISA from './pages/CountryISA'
import Projects from './pages/Projects'
import ProjectDetail from './pages/ProjectDetail'
import Register from './pages/Register'
import Login from './pages/Login'
import ForgotPassword from './pages/ForgotPassword'
import ResetPassword from './pages/ResetPassword'
import Account from './pages/Account'
import ConfirmEmail from './pages/ConfirmEmail'
import KycReminderBanner from './components/KycReminderBanner/KycReminderBanner'
import Pillar from './pages/Pillar'
import Pillars from './pages/Pillars'
import About from './pages/About'
import Methodology from './pages/Methodology'
import Participate from './pages/Participate'
import Data from './pages/Data'
import AmarDetail from './pages/AmarDetail'
import ConflictEconomyDetail from './pages/ConflictEconomyDetail'
import IosaDetail from './pages/IosaDetail'
import './App.css'

function Layout() {
  return (
    <>
      <AppHeader />
      <KycReminderBanner />
      <main className="main-content">
        <Outlet />
      </main>
      <AppFooter />
    </>
  )
}

const router = createBrowserRouter([
  // Route independante -- volontairement hors du Layout (pas de header
  // complet avec navigation). Accedee via un lien/QR personnel (flyer,
  // e-mail d'invitation), pas par une navigation normale dans le site.
  { path: '/confirm-email', element: <ConfirmEmail /> },
  {
    element: <Layout />,
    children: [
      { path: '/',                               element: <Home /> },
      { path: '/countries',                      element: <Countries /> },
      { path: '/country/:iso3',                  element: <Country /> },
      { path: '/country/:iso3/isa',              element: <CountryISA /> },
      { path: '/country/:iso3/projects',         element: <Projects /> },
      { path: '/country/:iso3/projects/:id',     element: <ProjectDetail /> },
      { path: '/country/:iso3/amar',             element: <AmarDetail /> },
      { path: '/country/:iso3/conflict-economy', element: <ConflictEconomyDetail /> },
      { path: '/country/:iso3/iosa',             element: <IosaDetail /> },
      { path: '/country/:iso3/poa',              element: <IosaDetail /> },
      { path: '/register',                       element: <Register /> },
      { path: '/login',                          element: <Login /> },
      { path: '/forgot-password',                element: <ForgotPassword /> },
      { path: '/reset-password',                 element: <ResetPassword /> },
      { path: '/mon-espace',                     element: <Account /> },
      { path: '/pillars',                        element: <Pillars /> },
      { path: '/pillar/:code',                   element: <Pillar /> },
      { path: '/about',                          element: <About /> },
      { path: '/methodology',                    element: <Methodology /> },
      { path: '/participate',                    element: <Participate /> },
      { path: '/data',                           element: <Data /> },
    ]
  }
])

export default function App() {
  return <RouterProvider router={router} />
}
