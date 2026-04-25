import { Wifi, Bluetooth, Radio, Satellite } from "lucide-react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export default function GTIoTEDULanding() {
  return (
    <div className="min-h-screen bg-slate-900 text-white">
      <nav className="flex items-center justify-between px-6 py-4 bg-slate-900/95 backdrop-blur-sm fixed w-full top-0 z-50">
        <span className="text-xl font-bold">GT IoTEdu Beta </span>
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
          <a
            href="https://gt-iotedu.github.io/"
            target="_blank"
            rel="noopener noreferrer"
          >
            <Badge className="mb-8 bg-blue-600/20 text-blue-300 border-blue-500/30 px-4 py-2 hover:bg-blue-600/30 cursor-pointer transition-colors">
              Landing Page
            </Badge>
          </a>

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

          <div className="flex justify-center items-center space-x-8 mb-12 opacity-60">
            <div className="flex items-center space-x-2">
              <Wifi className="w-6 h-6 text-blue-400" />
              <span className="text-sm text-slate-400">WiFi</span>
            </div>
            <div className="flex items-center space-x-2">
              <Bluetooth className="w-6 h-6 text-blue-400" />
              <span className="text-sm text-slate-400">Bluetooth</span>
            </div>
            <div className="flex items-center space-x-2">
              <Radio className="w-6 h-6 text-green-400" />
              <span className="text-sm text-slate-400">LoRa</span>
            </div>
            <div className="flex items-center space-x-2">
              <Satellite className="w-6 h-6 text-purple-400" />
              <span className="text-sm text-slate-400">5G</span>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
