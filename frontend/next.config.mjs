/** @type {import('next').NextConfig} */
const apiInternalBase = (process.env.API_INTERNAL_URL || "http://localhost:8000").replace(/\/$/, "");

const nextConfig = {
  eslint: {
    ignoreDuringBuilds: true,
  },
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    unoptimized: true,
  },
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: `${apiInternalBase}/api/:path*`,
      },
    ];
  },
}

export default nextConfig
