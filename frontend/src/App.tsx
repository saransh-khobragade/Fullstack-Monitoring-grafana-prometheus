import './App.css';
import type { ReactElement } from 'react';
import { useState } from 'react';
import { ThemeProvider } from 'next-themes';
import { AuthProvider, useAuth } from '@/contexts/AuthContext';
import { AuthPage } from '@/components/auth/AuthPage';
import { Dashboard } from '@/components/dashboard/Dashboard';
import { Toaster } from '@/components/ui/sonner';

function AppContent(): ReactElement {
  const { user, isLoading } = useAuth();
  const [isLogin, setIsLogin] = useState(true);

  if (isLoading) {
    return (
      <div className='min-h-screen flex items-center justify-center'>
        <div className='text-lg'>Loading...</div>
      </div>
    );
  }

  return user !== null ? <Dashboard /> : <AuthPage isLogin={isLogin} setIsLogin={setIsLogin} />;
}

function App(): ReactElement {
  return (
    <ThemeProvider
      attribute="class"
      defaultTheme="dark"
      enableSystem={false}
      disableTransitionOnChange
    >
      <AuthProvider>
        <div className='min-h-screen bg-background'>
          <AppContent />
          <Toaster />
        </div>
      </AuthProvider>
    </ThemeProvider>
  );
}

export default App;
