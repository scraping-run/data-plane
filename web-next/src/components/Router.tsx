"use client";

import { useEffect, useState } from "react";
import { useRouter, usePathname } from "next/navigation";
import { css, Global } from "@emotion/react";
import { useTranslation } from "react-i18next";
import RouteElement from "../routes";
import UpgradePrompt from "./UpgradePrompt";
import useAuthStore from "../pages/auth/store";
import useSiteSettingStore from "../pages/siteSetting";
import { CHAKRA_UI_COLOR_MODE_KEY } from "../constants";

const GlobalStyles = css`
  .js-focus-visible :focus:not([data-focus-visible-added]) {
    outline: none;
    box-shadow: none;
  }
`;

const useDocumentTitle = (titleKey: string, defaultTitle: string) => {
  const { t } = useTranslation();

  useEffect(() => {
    document.title = t(titleKey, defaultTitle);
  }, [t, titleKey, defaultTitle]);
};

export default function Router() {
  const { loading, user } = useAuthStore();
  const siteSettings = useSiteSettingStore((state) => state.siteSettings);
  const [isReady, setIsReady] = useState(false);

  useDocumentTitle("HomePage.NavBar.title", "data-plane");

  useEffect(() => {
    setIsReady(true);
    
    const colorMode = localStorage.getItem(CHAKRA_UI_COLOR_MODE_KEY);
    if (colorMode) {
      document.documentElement.setAttribute('data-theme', colorMode);
    }
  }, []);

  useEffect(() => {
    if (siteSettings?.laf_version) {
      console.log("🚀 ~ data-plane version:", siteSettings?.laf_version);
    }
  }, [siteSettings]);

  if (!isReady || loading) {
    return null;
  }

  return (
    <>
      <Global styles={GlobalStyles} />
      <RouteElement />
      <UpgradePrompt />
    </>
  );
}