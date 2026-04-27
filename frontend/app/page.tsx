import { ExternalLink } from "lucide-react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export default function GTIoTEDULanding() {
  return (
    <div className="min-h-screen bg-slate-900 text-white">
      <nav className="flex items-center justify-between px-6 py-4 bg-slate-900/95 backdrop-blur-sm fixed w-full top-0 z-50">
        <span className="text-xl font-bold">GT IoTEdu Beta MVP1</span>
        <Link href="/login">
          <Button
            variant="outline"
            className="border-slate-600 text-white hover:bg-slate-800 bg-transparent"
          >
            Login
          </Button>
        </Link>
      </nav>

      <section className="pt-24 pb-16 px-6 bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900">
        <div className="max-w-6xl mx-auto text-center">
          <div className="mb-10 flex justify-center">
            <a
              href="https://gt-iotedu.github.io/"
              target="_blank"
              rel="noopener noreferrer"
              className="group"
            >
              <div className="rounded-xl border border-blue-500/40 bg-blue-500/10 px-5 py-4 shadow-lg shadow-blue-900/30 transition-all duration-200 hover:bg-blue-500/20 hover:scale-[1.01]">
                <Badge className="mb-2 bg-blue-600/20 text-blue-300 border-blue-500/30 px-4 py-2">
                  Link oficial
                </Badge>
                <div className="flex items-center justify-center gap-2 text-base md:text-lg font-semibold text-blue-200">
                  Landing Page oficial do projeto
                  <ExternalLink className="w-4 h-4 transition-transform group-hover:translate-x-0.5" />
                </div>
              </div>
            </a>
          </div>

          <h1 className="text-6xl md:text-8xl font-bold mb-8">
            <span className="text-white">GT IoT</span>
            <br />
            <span className="bg-gradient-to-r from-blue-400 via-green-400 to-blue-600 bg-clip-text text-transparent">
              EDU
            </span>
          </h1>

          <p className="text-xl md:text-2xl text-slate-300 mb-12 max-w-4xl mx-auto leading-relaxed">
            Plataforma inovadora para{" "}
            <span className="text-blue-400 font-semibold">
              simplificar e proteger
            </span>{" "}
            o uso de dispositivos IoT em
            <span className="text-green-400 font-semibold">
              {" "}
              instituições acadêmicas
            </span>
            , oferecendo
            <span className="text-blue-400 font-semibold">
              {" "}
              cadastro fácil e redes otimizadas
            </span>
            .
          </p>

        </div>
      </section>
    </div>
  );
}
