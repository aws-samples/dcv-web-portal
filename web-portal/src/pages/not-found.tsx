/**
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 */
import * as React from "react";
import { I18n } from "@aws-amplify/core";
import { Alert, Container, Header } from "@cloudscape-design/components";

export default function NotFound() {
  return (
    <>
      <div className="content">
        <div className="main">
          <Container header={<Header variant="h1">404. {I18n.get("Not Found")}</Header>}>
          <Alert
              visible={true}
              dismissAriaLabel="Close alert"
              type="error"
              header="404"
            >
              The page you are looking for does not exist.
            </Alert>
          </Container>
        </div>
      </div>
      <br />
    </>
  );
}
