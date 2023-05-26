/**
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 */
import { Auth } from "aws-amplify";
import { region, userPoolId, userPoolWebClientId, identityPoolId, apiEndpoint } from "./config";

export default {
  Auth: {
    region,
    userPoolId,
    userPoolWebClientId,
    identityPoolId
  },
  API: {
    endpoints: [
      {
        name: "SessionsAPI",
        endpoint: apiEndpoint,
        custom_header: async () => ({
          Authorization: `Bearer ${(await Auth.currentSession())
            .getIdToken()
            .getJwtToken()}`,
        }),
      },
    ],
  },
};
