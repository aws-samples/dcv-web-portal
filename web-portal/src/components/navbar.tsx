/**
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 */
import * as React from "react";
import { I18n } from "@aws-amplify/core";
import { withAuthenticator } from "@aws-amplify/ui-react";
import { TopNavigation, TopNavigationProps } from "@cloudscape-design/components";


type NavbarProps = React.PropsWithChildren<{
  signOut: () => void;
  user: {
    username: string;
    signInUserSession: {
      accessToken: {
        payload: { [key: string]: string[] };
      };
    };
  };
}>;

function Navbar({ signOut, user }: NavbarProps) {
  const { payload } = user.signInUserSession.accessToken;
  const groups = payload["cognito:groups"] || [];
  const isAdmin = groups.includes("admin");
  const utilities:TopNavigationProps.Utility[] = [];

  function handleProfileClick(id: any): void {
    if (id === "signout") {
      signOut();
    }
  }

  utilities.push({
    type: "button",
    text: I18n.get("Sessions"),
    href: "/",
    external: false
  });

  if (isAdmin) {
    utilities.push({
      type: "button",
      iconName: "settings",
      text: I18n.get("Admin"),
      href: "/admin",
      external: false
    });
  }
  utilities.push({
    type: "menu-dropdown",
    text: user.username,
    iconName: "user-profile",
    items: [
      { id: "signout", text: I18n.get("Sign out") }
    ],
   onItemClick: ({detail}) => handleProfileClick(detail.id)
  });

  return (
    <div id="navbar">
      <TopNavigation
        identity={{
          href: "/",
          title: "NICE DCV Web Portal",
          logo: {
            src:
              "data:image/svg+xml;base64,PHN2ZwogIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIKICB3aWR0aD0iNDIiCiAgaGVpZ2h0PSI0MiIKICBmaWxsPSIjZmZmZmZmIgogIHZpZXdCb3g9IjAgMCAxNiAxNiI+CiAgPHBhdGggZD0iTTggMWExIDEgMCAwIDEgMS0xaDZhMSAxIDAgMCAxIDEgMXYxNGExIDEgMCAwIDEtMSAxSDlhMSAxIDAgMCAxLTEtMVYxWm0xIDEzLjVhLjUuNSAwIDEgMCAxIDAgLjUuNSAwIDAgMC0xIDBabTIgMGEuNS41IDAgMSAwIDEgMCAuNS41IDAgMCAwLTEgMFpNOS41IDFhLjUuNSAwIDAgMCAwIDFoNWEuNS41IDAgMCAwIDAtMWgtNVpNOSAzLjVhLjUuNSAwIDAgMCAuNS41aDVhLjUuNSAwIDAgMCAwLTFoLTVhLjUuNSAwIDAgMC0uNS41Wk0xLjUgMkExLjUgMS41IDAgMCAwIDAgMy41djdBMS41IDEuNSAwIDAgMCAxLjUgMTJINnYyaC0uNWEuNS41IDAgMCAwIDAgMUg3di00SDEuNWEuNS41IDAgMCAxLS41LS41di03YS41LjUgMCAwIDEgLjUtLjVIN1YySDEuNVoiIC8+Cjwvc3ZnPg==",
            alt: "NICE DCV Web Portal"
          }
        }}
        utilities={utilities}
        i18nStrings={{
          overflowMenuTriggerText: "More",
          overflowMenuTitleText: "All"
        }}
      />
    </div>
  );
}

export default withAuthenticator(Navbar, {
  hideSignUp: true,
});


