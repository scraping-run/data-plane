"use client";

import { useEffect } from "react";
import { loader } from "@monaco-editor/react";
import * as Sentry from "@sentry/react";
import UpgradePrompt from "../components/UpgradePrompt";
import useAuthStore from "../pages/auth/store";
import useSiteSettingStore from "../pages/siteSetting";
import Router from "../components/Router";
import "../App.css";

// Configure Monaco Editor
loader.config({
  paths: { vs: "/js/monaco-editor.0.43.0" },
});

// Initialize Sentry
if (typeof window !== 'undefined' && ["data-plane.run", "scraping.run"].includes(window.location.hostname)) {
  const commitId = process.env.NEXT_PUBLIC_GITHUB_SHA;

  Sentry.init({
    dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
    release: `data-plane@${commitId}`,
    integrations: [
      new Sentry.BrowserTracing(),
      new Sentry.Replay(),
    ],
    tracesSampleRate: 1.0,
    replaysSessionSampleRate: 0.1,
    replaysOnErrorSampleRate: 1.0,
  });
}

// Polyfill for aws-sdk
if (typeof window !== 'undefined' && typeof (window as any).global === "undefined") {
  (window as any).global = window;
}

export default function Home() {
  return <Router />;
}
