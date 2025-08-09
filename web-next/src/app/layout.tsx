"use client";

import type { Metadata } from "next";
import { Inter } from "next/font/google";
import { ChakraProvider, createSystem, defaultConfig } from "@chakra-ui/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import "./globals.css";
import "@/utils/i18n";
import theme from "@/chakraTheme";
import { Suspense, useState } from "react";
import "simplebar-react/dist/simplebar.min.css";
import "focus-visible/dist/focus-visible";

const inter = Inter({ subsets: ["latin"] });

const system = createSystem(defaultConfig);

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: {
      queries: {
        refetchOnWindowFocus: false,
        retry: false,
        staleTime: 0,
        gcTime: 0,
      },
    },
  }));

  return (
    <html lang="en">
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <link rel="icon" href="/favicon.ico" />
        <title>laf</title>
        <meta name="description" content="life is short, you need laf:)" />
      </head>
      <body className={inter.className}>
        <QueryClientProvider client={queryClient}>
          <ChakraProvider value={system}>
            <Suspense fallback={null}>
              {children}
            </Suspense>
          </ChakraProvider>
        </QueryClientProvider>
      </body>
    </html>
  );
}
