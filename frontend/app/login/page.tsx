"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { Wifi, ArrowLeft, KeyRound } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { useRouter } from "next/navigation";

const API_BASE = (process.env.NEXT_PUBLIC_API_BASE ?? "").trim();
const authPath = (path: string): string => (API_BASE ? `${API_BASE}${path}` : path);

// Liga/desliga cada provedor de login. Trocar `true` ↔ `false` aqui
// é o único lugar que precisa mudar pra habilitar/ocultar uma opção
// na tela de login.
const PROVIDERS_ENABLED = {
  cafe: true,
  google: true,
  iotedu: true,
  anonshield: true,
} as const;

export default function LoginPage() {
  const [isLoading, setIsLoading] = useState(false);
  const router = useRouter();
  const [idpLoadingProvider, setIdpLoadingProvider] = useState<string | null>(null);
  const popupRef = useRef<Window | null>(null);
  const gotMessageRef = useRef(false);
  const pollTimerRef = useRef<number | null>(null);
  const timeoutRef = useRef<number | null>(null);
  const idpPopupRef = useRef<Window | null>(null);
  const idpGotMessageRef = useRef(false);
  const idpPollTimerRef = useRef<number | null>(null);
  const idpTimeoutRef = useRef<number | null>(null);

  async function handleGoogleLogin() {
    setIsLoading(true);
    try {
      console.log("Iniciando login com Google...");

      // Verifica se o backend está acessível antes de abrir o popup
      try {
        const response = await fetch(authPath("/api/auth/health"), {
          method: "HEAD",
          credentials: "include",
        });
        if (!response.ok) {
          throw new Error(`Health check falhou com status ${response.status}`);
        }
        console.log("Backend está acessível:", authPath("/api/auth/health"));
      } catch (err) {
        console.error("Erro ao verificar backend:", err);
        alert(
          "Servidor backend não está acessível. Verifique a configuração de API do ambiente."
        );
        setIsLoading(false);
        return;
      }

      // Abre uma nova janela para o fluxo OAuth
      const popup = window.open(
        authPath("/api/auth/google/login"),
        "googleLogin",
        "width=500,height=600"
      );

      if (!popup) {
        console.error("Popup bloqueado pelo navegador!");
        alert("Permita popups para este site para fazer login com Google");
        setIsLoading(false);
        return;
      }

      console.log("Popup aberto, aguardando autenticação...");
      popupRef.current = popup;

      // Listener para receber mensagem do popup
      const onMessage = function onMessage(event: MessageEvent) {
        console.log("Mensagem recebida:", event.data);
        console.log("Origem da mensagem:", event.origin);

        if (event.data?.provider === "google") {
          gotMessageRef.current = true;
          setIsLoading(false);
          console.log("Usuário autenticado:", event.data);
          window.removeEventListener("message", onMessage);

          // Persistir dados básicos com segurança no navegador e redirecionar sem querystring
          try {
            const payload = {
              provider: "google",
              name: event.data.name || "",
              email: event.data.email || "",
              picture: event.data.picture || "",
              user_id: event.data.user_id || null,
              permission: event.data.permission || "USER",
            };
            window.localStorage.setItem("auth:user", JSON.stringify(payload));
          } catch (e) {
            console.warn("Falha ao salvar dados do usuário no localStorage:", e);
          }
          router.push("/dashboard");
        }

        if (event.data?.error) {
          setIsLoading(false);
          console.error("Erro no login Google:", event.data.error);
          window.removeEventListener("message", onMessage);
        }
      };
      window.addEventListener("message", onMessage, { once: true });

      // Poll fechamento do popup
      if (pollTimerRef.current) window.clearInterval(pollTimerRef.current);
      // @ts-ignore - setInterval retorna number no browser
      pollTimerRef.current = window.setInterval(() => {
        if (!popupRef.current || popupRef.current.closed) {
          window.clearInterval(pollTimerRef.current!);
          pollTimerRef.current = null;
          if (!gotMessageRef.current) {
            console.warn("Popup fechado sem finalizar login.");
            setIsLoading(false);
            window.removeEventListener("message", onMessage);
          }
        }
      }, 500);

      // Timeout de segurança: encerra loading se nada acontecer em 60s
      if (timeoutRef.current) window.clearTimeout(timeoutRef.current);
      // @ts-ignore
      timeoutRef.current = window.setTimeout(() => {
        if (!gotMessageRef.current) {
          console.warn("Tempo de login excedido.");
          try { popupRef.current?.close(); } catch {}
          setIsLoading(false);
          window.removeEventListener("message", onMessage);
          alert("Não foi possível completar o login. Tente novamente.");
        }
      }, 60000);
    } catch (err) {
      setIsLoading(false);
      console.error("Erro ao iniciar login Google:", err);
      if (err instanceof Error) {
        alert(`Erro ao iniciar login: ${err.message}`);
      } else {
        alert("Erro ao iniciar login Google.");
      }
    }
  }

  async function handleIdpLogin(provider: "iotedu" | "anonshield") {
    setIdpLoadingProvider(provider);
    try {
      try {
        const response = await fetch(authPath("/api/auth/health"), {
          method: "HEAD",
          credentials: "include",
        });
        if (!response.ok) {
          throw new Error(`Health check falhou com status ${response.status}`);
        }
      } catch (err) {
        console.error("Erro ao verificar backend:", err);
        alert("Servidor backend não está acessível.");
        setIdpLoadingProvider(null);
        return;
      }

      const popup = window.open(
        authPath(`/api/auth/${provider}/login`),
        `${provider}IdpLogin`,
        "width=500,height=700"
      );
      if (!popup) {
        alert("Permita popups para este site para fazer login");
        setIdpLoadingProvider(null);
        return;
      }
      idpPopupRef.current = popup;
      idpGotMessageRef.current = false;

      const onMessage = (event: MessageEvent) => {
        if (event.data?.provider !== provider) return;
        idpGotMessageRef.current = true;
        setIdpLoadingProvider(null);
        window.removeEventListener("message", onMessage);
        try {
          window.localStorage.setItem(
            "auth:user",
            JSON.stringify({
              provider,
              name: event.data.name || "",
              email: event.data.email || "",
              picture: event.data.picture || "",
              user_id: event.data.user_id || null,
              permission: event.data.permission || "USER",
            })
          );
        } catch (e) {
          console.warn("Falha ao salvar dados do usuário:", e);
        }
        router.push("/dashboard");
      };
      window.addEventListener("message", onMessage);

      if (idpPollTimerRef.current) window.clearInterval(idpPollTimerRef.current);
      idpPollTimerRef.current = window.setInterval(() => {
        if (!idpPopupRef.current || idpPopupRef.current.closed) {
          window.clearInterval(idpPollTimerRef.current!);
          idpPollTimerRef.current = null;
          if (!idpGotMessageRef.current) {
            setIdpLoadingProvider(null);
            window.removeEventListener("message", onMessage);
          }
        }
      }, 500);

      if (idpTimeoutRef.current) window.clearTimeout(idpTimeoutRef.current);
      idpTimeoutRef.current = window.setTimeout(() => {
        if (!idpGotMessageRef.current) {
          try { idpPopupRef.current?.close(); } catch {}
          setIdpLoadingProvider(null);
          window.removeEventListener("message", onMessage);
          alert("Não foi possível completar o login. Tente novamente.");
        }
      }, 60000);
    } catch (err) {
      setIdpLoadingProvider(null);
      console.error("Erro ao iniciar login IDP:", err);
      alert(err instanceof Error ? `Erro: ${err.message}` : "Erro ao iniciar login.");
    }
  }

  useEffect(() => {
    return () => {
      if (pollTimerRef.current) {
        window.clearInterval(pollTimerRef.current);
        pollTimerRef.current = null;
      }
      if (timeoutRef.current) {
        window.clearTimeout(timeoutRef.current);
        timeoutRef.current = null;
      }
      if (idpPollTimerRef.current) {
        window.clearInterval(idpPollTimerRef.current);
        idpPollTimerRef.current = null;
      }
      if (idpTimeoutRef.current) {
        window.clearTimeout(idpTimeoutRef.current);
        idpTimeoutRef.current = null;
      }
    };
  }, []);

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 flex flex-col">
      {/* Header com navegação de volta para a landing page */}
      <header className="px-6 py-4 flex items-center">
        <Link
          href="/"
          className="flex items-center text-blue-400 hover:text-blue-300 transition-colors"
        >
          <ArrowLeft className="h-5 w-5 mr-2" />
          <span>Voltar</span>
        </Link>
      </header>

      {/* Conteúdo principal centralizado */}
      <main className="flex-1 flex flex-col items-center justify-center p-6">
        <div className="text-center mb-10">
          {/* Removido o h1 com "Login - GT IoT-Edu" */}
          <div className="flex items-center justify-center space-x-3">
            <div className="relative">
              <Wifi className="h-10 w-10 text-blue-400" />
              <div className="absolute -top-1 -right-1 w-3 h-3 bg-green-400 rounded-full animate-pulse"></div>
            </div>
            <span className="text-4xl font-bold text-blue-400">GT IoT-Edu</span>
          </div>
        </div>

        <div className="w-full max-w-md space-y-6">

          {/* CAFe — card grande institucional (estilo padrão das federações) */}
          {PROVIDERS_ENABLED.cafe && (
            <Card className="border border-slate-700 bg-slate-800/30 p-4 text-center">
              <div className="mb-4">
                <Image
                  src="/images/cafe-logo.png"
                  alt="CAFe — Comunidade Acadêmica Federada"
                  width={240}
                  height={80}
                  className="mx-auto"
                />
              </div>
              <Button
                className="w-full bg-blue-600 hover:bg-blue-700 text-white"
                onClick={() => alert("Redirecionando para autenticação CAFe...")}
              >
                Clique aqui para acessar pelo login institucional
              </Button>
            </Card>
          )}

          {/* OAuth/OIDC — card secundário, agrupa Google + IdPs */}
          <Card className="border border-slate-700 bg-slate-800/40 p-6">
            <h2 className="text-base font-medium text-slate-300 mb-5 text-center">
              Ou entre por outra conta
            </h2>

          <div className="space-y-3">
            {PROVIDERS_ENABLED.google && (
              <Button
                variant="outline"
                className="w-full justify-start border-slate-600 bg-slate-800/60 text-slate-100 hover:bg-slate-700 h-11"
                onClick={handleGoogleLogin}
                disabled={isLoading || idpLoadingProvider !== null}
              >
                <svg aria-hidden="true" className="w-5 h-5 mr-3" viewBox="0 0 24 24">
                  <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
                  <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
                  <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
                  <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
                </svg>
                {isLoading ? "Conectando..." : "Continuar com Google"}
              </Button>
            )}

            {PROVIDERS_ENABLED.iotedu && (
              <Button
                variant="outline"
                className="w-full justify-start border-slate-600 bg-slate-800/60 text-slate-100 hover:bg-slate-700 h-11"
                onClick={() => handleIdpLogin("iotedu")}
                disabled={idpLoadingProvider !== null || isLoading}
              >
                <Image src="/idp-iotedu.svg" alt="" aria-hidden="true" width={20} height={20} className="mr-3" />
                {idpLoadingProvider === "iotedu" ? "Conectando..." : "Continuar com IdP IoTEdu"}
              </Button>
            )}

            {PROVIDERS_ENABLED.anonshield && (
              <Button
                variant="outline"
                className="w-full justify-start border-slate-600 bg-slate-800/60 text-slate-100 hover:bg-slate-700 h-11"
                onClick={() => handleIdpLogin("anonshield")}
                disabled={idpLoadingProvider !== null || isLoading}
              >
                <Image src="/idp-anonshield.svg" alt="" aria-hidden="true" width={20} height={20} className="mr-3" />
                {idpLoadingProvider === "anonshield" ? "Conectando..." : "Continuar com IdP AnonShield"}
              </Button>
            )}
          </div>

          {/* Recuperação de popup (mantido para Google que abre popup) */}
          {isLoading && (
            <div className="mt-4 flex gap-2 justify-center text-xs">
              <button
                className="text-blue-400 hover:text-blue-300 underline"
                onClick={() => {
                  try {
                    const p = window.open(authPath("/api/auth/google/login"), "googleLogin", "width=500,height=600");
                    if (p) { p.focus(); popupRef.current = p; }
                  } catch {}
                }}
              >
                Reabrir popup
              </button>
              <span className="text-slate-600">·</span>
              <button
                className="text-slate-400 hover:text-slate-300 underline"
                onClick={() => {
                  try { popupRef.current?.close(); } catch {}
                  if (pollTimerRef.current) { window.clearInterval(pollTimerRef.current); pollTimerRef.current = null; }
                  if (timeoutRef.current) { window.clearTimeout(timeoutRef.current); timeoutRef.current = null; }
                  setIsLoading(false);
                }}
              >
                Cancelar
              </button>
            </div>
          )}
          </Card>
        </div>

        {/* Footer */}
        <div className="mt-10 text-center">
          <Link href="#" className="text-blue-400 hover:text-blue-300 text-sm">
            Aviso de Privacidade
          </Link>
          <p className="text-xs text-slate-500 mt-2">
            © 2025 GT-IoTEDU Todos os direitos reservados.
          </p>
        </div>
      </main>
    </div>
  );
}
