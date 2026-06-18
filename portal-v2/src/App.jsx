import { createBrowserRouter, RouterProvider } from 'react-router-dom'
import Home from './pages/Home'
import Countries from './pages/Countries'
import Country from './pages/Country'
import Projects from './pages/Projects'
import ProjectDetail from './pages/ProjectDetail'
import Register from './pages/Register'
import Pillar from './pages/Pillar'
import About from './pages/About'
import Methodology from './pages/Methodology'
import Participate from './pages/Participate'
import Data from './pages/Data'

const router = createBrowserRouter([
  { path: '/',                            element: <Home /> },
  { path: '/countries',                   element: <Countries /> },
  { path: '/country/:iso3',               element: <Country /> },
  { path: '/country/:iso3/projects',      element: <Projects /> },
  { path: '/country/:iso3/projects/:id',  element: <ProjectDetail /> },
  { path: '/register',                    element: <Register /> },
  { path: '/pillar/:code',                element: <Pillar /> },
  { path: '/about',                       element: <About /> },
  { path: '/methodology',                 element: <Methodology /> },
  { path: '/participate',                 element: <Participate /> },
  { path: '/data',                        element: <Data /> },
])

export default function App() {
  return <RouterProvider router={router} />
}
