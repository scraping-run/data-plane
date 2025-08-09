import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

interface IframeMessage {
  type: "AUTH_TOKEN" | "NAVIGATE" | "RESIZE";
  token?: string;
  appId?: string;
  pageId?: string;
  height?: number;
}

export const useIframeAuth = () => {
  const navigate = useNavigate();
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isIframe, setIsIframe] = useState(false);

  useEffect(() => {
    // Check if running in iframe
    const inIframe = window.parent !== window;
    setIsIframe(inIframe);

    if (!inIframe) {
      console.warn("Not running in iframe context");
      return;
    }

    const handleMessage = (event: MessageEvent) => {
      // In production, you should validate event.origin
      // For now, we'll accept messages from any origin
      // TODO: Add origin whitelist validation

      try {
        const message: IframeMessage = event.data;

        switch (message.type) {
          case "AUTH_TOKEN":
            if (message.token) {
              // Store token in localStorage
              localStorage.setItem("token", message.token);
              setIsAuthenticated(true);

              // Send confirmation to parent
              window.parent.postMessage(
                {
                  type: "AUTH_SUCCESS",
                  timestamp: Date.now(),
                },
                "*",
              );
            }
            break;

          case "NAVIGATE":
            if (message.appId && message.pageId) {
              navigate(`/embed/app/${message.appId}/${message.pageId}`);
            }
            break;

          case "RESIZE":
            if (message.height) {
              document.body.style.height = `${message.height}px`;
            }
            break;

          default:
            console.log("Unknown message type:", message.type);
        }
      } catch (error) {
        console.error("Error handling iframe message:", error);
      }
    };

    window.addEventListener("message", handleMessage);

    // Request token from parent
    window.parent.postMessage({ type: "REQUEST_TOKEN" }, "*");

    return () => {
      window.removeEventListener("message", handleMessage);
    };
  }, [navigate]);

  // Send height updates to parent
  useEffect(() => {
    if (!isIframe) return;

    const sendHeight = () => {
      const height = document.body.scrollHeight;
      window.parent.postMessage(
        {
          type: "HEIGHT_UPDATE",
          height,
        },
        "*",
      );
    };

    // Send initial height
    sendHeight();

    // Watch for height changes
    const observer = new ResizeObserver(sendHeight);
    observer.observe(document.body);

    return () => {
      observer.disconnect();
    };
  }, [isIframe]);

  return {
    isAuthenticated,
    isIframe,
  };
};
