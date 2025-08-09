import { useEffect } from "react";
import { useParams } from "react-router-dom";
import { Box, Center, Spinner, Text } from "@chakra-ui/react";

import { Pages } from "@/constants/index";

import { useIframeAuth } from "./useIframeAuth";

import DatabasePage from "@/pages/app/database";
import FunctionPage from "@/pages/app/functions";
import StoragePage from "@/pages/app/storages";
import useGlobalStore from "@/pages/globalStore";

function EmbedApp() {
  const { visitedViews, currentPageId, setCurrentPage } = useGlobalStore();
  const { isAuthenticated, isIframe } = useIframeAuth();
  const params = useParams();
  const { pageId = Pages.function } = params;

  useEffect(() => {
    setCurrentPage(pageId);
  }, [pageId, setCurrentPage]);

  // Show loading while authenticating
  if (isIframe && !isAuthenticated) {
    return (
      <Center height="100vh">
        <Box textAlign="center">
          <Spinner size="lg" mb={4} />
          <Text>Authenticating...</Text>
        </Box>
      </Center>
    );
  }

  // Show warning if not in iframe
  if (!isIframe) {
    return (
      <Center height="100vh">
        <Box textAlign="center">
          <Text fontSize="lg" fontWeight="bold" mb={2}>
            This page must be loaded in an iframe
          </Text>
          <Text color="gray.500">Please access this page from the parent application</Text>
        </Box>
      </Center>
    );
  }

  return (
    <div className="h-full w-full">
      {[
        {
          pageId: Pages.function,
          component: FunctionPage,
        },
        {
          pageId: Pages.database,
          component: DatabasePage,
        },
        {
          pageId: Pages.storage,
          component: StoragePage,
        },
      ].map((item) =>
        visitedViews.includes(item.pageId) ? (
          <div
            key={item.pageId}
            className={
              currentPageId === item.pageId && visitedViews.includes(currentPageId)
                ? "flex h-full"
                : "hidden"
            }
          >
            <item.component />
          </div>
        ) : null,
      )}
    </div>
  );
}

export default EmbedApp;
