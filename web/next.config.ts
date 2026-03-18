import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "export",
  basePath: "/PilotMirror",
  trailingSlash: true,
  images: { unoptimized: true },
};

export default nextConfig;
