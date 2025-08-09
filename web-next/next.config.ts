import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  webpack: (config, { isServer }) => {
    if (!isServer) {
      config.resolve.fallback = {
        ...config.resolve.fallback,
        fs: false,
      };
    }
    
    // Monaco Editor 설정
    config.module.rules.push({
      test: /\.wasm$/,
      type: "webassembly/async",
    });

    return config;
  },
  async rewrites() {
    const devServerUrl = process.env.NEXT_PUBLIC_DEV_SERVER_URL || "http://localhost:3000";
    return [
      {
        source: "/v1/:path*",
        destination: `${devServerUrl}/v1/:path*`,
      },
    ];
  },
  // 정적 파일 서빙을 위한 설정
  async headers() {
    return [
      {
        source: "/js/:path*",
        headers: [
          {
            key: "Cache-Control",
            value: "public, max-age=31536000, immutable",
          },
        ],
      },
    ];
  },
};

export default nextConfig;
