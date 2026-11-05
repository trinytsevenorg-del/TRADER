import { HashRouter, Navigate, NavLink, Route, Routes, useLocation } from 'react-router-dom';
import { AppProvider, useApp } from './lib/app';
import { configurado, conviteGuardado } from './lib/supabase';
import { Carregando, Icone } from './components/ui';
import Login from './pages/Login';
import Convite from './pages/Convite';
import CriarOrg from './pages/CriarOrg';
import Painel from './pages/Painel';
import Elenco from './pages/Elenco';
import Agenda from './pages/Agenda';
import Evento from './pages/Evento';
import Mes from './pages/Mes';
import Ficha from './pages/Ficha';
import Config from './pages/Config';
import Admin from './pages/Admin';

function Nav() {
  const { org, podeConfigurar } = useApp();
  if (!org || org.papel === 'jogador') return null;
  const itens = [
    { to: '/painel', nome: 'Painel', icone: 'painel' },
    { to: '/agenda', nome: 'Agenda', icone: 'agenda' },
    { to: '/mes', nome: 'Mês', icone: 'mes' },
    { to: '/elenco', nome: 'Elenco', icone: 'elenco' },
    { to: '/config', nome: podeConfigurar ? 'Ajustes' : 'Conta', icone: 'config' },
  ];
  return (
    <nav className="nav" aria-label="Principal">
      <div className="nav-in">
        {itens.map((i) => (
          <NavLink key={i.to} to={i.to} className={({ isActive }) => (isActive ? 'ativo' : '')}><Icone nome={i.icone} />{i.nome}</NavLink>
        ))}
      </div>
    </nav>
  );
}

function Rotas() {
  const { session, carregando, org, euJogador, souAdmin } = useApp();
  const loc = useLocation();
  if (!configurado) return <div className="centro"><div className="caixa erro">Configure VITE_SUPABASE_URL e VITE_SUPABASE_ANON_KEY (veja o README).</div></div>;
  if (loc.pathname.startsWith('/convite/')) return <Routes><Route path="/convite/:token" element={<Convite />} /></Routes>;
  if (carregando) return <Carregando />;
  if (!session) return <Login />;
  const pendente = conviteGuardado();
  if (pendente) return <Navigate to={'/convite/' + pendente} replace />;
  if (souAdmin && loc.pathname === '/admin') return <div className="app"><Admin /></div>;
  if (!org) return <CriarOrg />;
  // fase 2: o jogador só vê a própria ficha
  if (org.papel === 'jogador') {
    return (
      <div className="app">
        <Routes>
          <Route path="/config" element={<Config />} />
          <Route path="*" element={euJogador ? <Ficha idFixo={euJogador.id} /> : <div className="vazio">Seu cadastro ainda não foi ligado pelo capitão.</div>} />
        </Routes>
      </div>
    );
  }
  return (
    <div className="app">
      <Routes>
        <Route path="/painel" element={<Painel />} />
        <Route path="/elenco" element={<Elenco />} />
        <Route path="/agenda" element={<Agenda />} />
        <Route path="/evento/:id" element={<Evento />} />
        <Route path="/mes" element={<Mes />} />
        <Route path="/jogador/:id" element={<Ficha />} />
        <Route path="/config" element={<Config />} />
        <Route path="*" element={<Navigate to="/painel" replace />} />
      </Routes>
      <Nav />
    </div>
  );
}

export default function App() {
  return (
    <HashRouter>
      <AppProvider><Rotas /></AppProvider>
    </HashRouter>
  );
}
