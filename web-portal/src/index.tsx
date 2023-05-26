/**
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 */
import { Amplify, I18n } from "aws-amplify";
import * as React from "react";
import * as ReactDOM from "react-dom";
import { translations } from "@aws-amplify/ui-react";
import { strings } from "./strings";
import App from "./app";
import "@cloudscape-design/global-styles/index.css";
import "@aws-amplify/ui-react/styles.css";
import "./styles/common.css";
import awsExports from "./aws-exports";

I18n.putVocabularies(translations);
I18n.putVocabularies(strings);

Amplify.configure(awsExports);
registerServiceWorker();

ReactDOM.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
  document.getElementById("root")
);

function registerServiceWorker() {
  if ("serviceWorker" in navigator) {
    window.addEventListener("load", () => {
      const url = `${process.env.PUBLIC_URL}/service-worker.js`;

      navigator.serviceWorker
        .register(url)
        .then((registration) => {
          registration.onupdatefound = () => {
            const installingWorker = registration.installing;
            installingWorker.onstatechange = () => {
              if (installingWorker.state === "installed") {
                if (navigator.serviceWorker.controller) {
                  console.log("New version is available");
                }
              }
            };
          };
        })
        .catch((error) => {
          console.error(error);
        });
    });
  }
}
