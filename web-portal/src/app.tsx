/**
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 */
import * as React from "react";
import { BrowserRouter} from "react-router-dom";
import { withAuthenticator } from "@aws-amplify/ui-react";

import "./styles/app.css";
import Router from "./router";

function App() {
  return (
    <BrowserRouter>
      <Router />
    </BrowserRouter>
  );
}

export default withAuthenticator(App, {
  hideSignUp: true,
});
