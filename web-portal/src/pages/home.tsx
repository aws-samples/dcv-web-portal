/**
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 */
import * as React from "react";
import { useState, useEffect } from "react";
import { gatewayEndpoint, gatewayPort } from "../config";
import { I18n } from "@aws-amplify/core";
import { withAuthenticator } from "@aws-amplify/ui-react";
import { useCollection } from '@cloudscape-design/collection-hooks';
import {
  AppLayout, Box,
  BreadcrumbGroup,
  Button,
  ButtonDropdown, ButtonDropdownProps,
  Header,
  Modal,
  Pagination,
  SpaceBetween,
  StatusIndicator,
  Table
} from "@cloudscape-design/components";
import {
  systemApi,
  SessionType,
  SessionStatus
} from "../common";
import Navbar from "../components/navbar";
import { PAGINATION_ARIA } from "../common/aria-labels";
import {TableProps} from "@cloudscape-design/components/table/interfaces";

const COLUMN_DEFINITIONS: ReadonlyArray<TableProps.ColumnDefinition<SessionType>> = [
  {
    id: 'id',
    header: I18n.get("Identifier"),
    cell: (item) => item.instanceId || "*",

  },
  {
    id: 'status',
    header: I18n.get("Status"),
    cell: (item) => (
        <StatusIndicator type={item.status === SessionStatus.Available ? 'success' :
                               item.status === SessionStatus.Pending ? 'pending' :
                               item.status === SessionStatus.Launching ||
                               item.status === SessionStatus.Terminating  ||
                               item.status === SessionStatus.Finalising ? 'loading' :
                               item.status === SessionStatus.Failed ||
                               item.status === SessionStatus.FailedTerminating ? 'error' : 'info'}>&nbsp;{I18n.get(item.status.toString())}</StatusIndicator>
    ),
  },
  {
    id: 'user',
    header: I18n.get("User"),
    cell: (item) => item.userId || "",
  },
  {
    id: 'templateName',
    header: 'Template Name',
    cell: (item) => item.launchTemplateName,
  },
  {
    id: 'templateVersion',
    header: 'Template Version',
    cell: (item) => item.launchTemplateVersion,
  },
];

type HomeProps = React.PropsWithChildren<{
  user: {
    username: string;
    signInUserSession: {
      idToken: {
        jwtToken: string;
      };
      accessToken: {
        payload: { [key: string]: string[] };
      };
    };
  };
}>;

function Home({ user }: HomeProps) {
  const [isLoading, setIsLoading] = useState(false);
  const [isStarting, setIsStarting] = useState(false);
  const [isTerminating, setIsTerminating] = useState(false);
  const [questionVisible, setQuestionVisible] = useState(false);
  const [sessions, setSessions] = useState<Array<SessionType> | null>(null);
  const [selectedSession, setSelectedSession] = useState<SessionType>();
  const [templates, setTemplates] = useState< ButtonDropdownProps.ItemOrGroup[]>([]);
  const [allocatedInstanceCount, setAllocatedInstanceCount] = useState<number>(0);

  const jwtToken = user.signInUserSession.idToken.jwtToken;
  const groups = user.signInUserSession.accessToken.payload["cognito:groups"] || [];
  const isAdmin = groups.includes("admin");

  const visibleColumns = isAdmin ? ['id', 'status', 'user', 'templateName', 'templateVersion'] : ['id', 'status', 'templateName', 'templateVersion'];

  // Initial data load
  useEffect(() => {
    const fetchSessions = async () => {
      setIsLoading(true);

      try {
        const { sessions } = await systemApi.listSessions();
        setSessions(sessions);

        const { templates } = await systemApi.getTemplates();
        setTemplates(templates.map((template) => ({
          id: template.name,
          text: template.name,
          iconName: "caret-right-filled"
        })));

        const count = await systemApi.getAllocatedInstanceCount();
        setAllocatedInstanceCount(count);

        if (
          sessions &&
          sessions.length > 0 &&
          sessions.every(
            (s) =>
              s.status === SessionStatus.Pending ||
              s.status === SessionStatus.Launching ||
              s.status === SessionStatus.Finalising
          )
        ) {
          setIsStarting(true);
        }

        if (
          sessions &&
          sessions.length > 0 &&
          sessions.every((s) => s.status === SessionStatus.Terminating)
        ) {
          setIsTerminating(true);
        }
      } catch (error) {
        console.error(error);
        alert(I18n.get("Sessions loading error"));

        setIsStarting(false);
      }

      setIsLoading(false);
    };

    fetchSessions();
  }, [setSessions, setIsLoading]);

  const {
    items,
    collectionProps,
    paginationProps
  } = useCollection(sessions || [], {
    pagination: { pageSize: 20},
    selection: {}
  });

  // Update sessions when starting or terminating
  useEffect(() => {
    let intervalId: NodeJS.Timer = null;

    const fetchSessions = async () => {
      intervalId = setInterval(async () => {
        if (!isStarting && !isTerminating) return;

        const { sessions } = await systemApi.listSessions();
        setSessions(sessions);
        const count = await systemApi.getAllocatedInstanceCount();
        setAllocatedInstanceCount(count);

        if (
          isStarting &&
          sessions &&
          sessions.length > 0 &&
          sessions.every(
            (s) =>
              s.status === SessionStatus.Failed ||
              s.status === SessionStatus.Available
          )
        ) {
          setIsStarting(false);
        }

        if (
          isTerminating &&
          sessions &&
          (sessions.length === 0 ||
            sessions.every((s) => s.status === SessionStatus.FailedTerminating))
        ) {
          setIsTerminating(false);
        }
      }, 5 * 1000);
    };

    fetchSessions();

    return () => {
      if (intervalId) {
        clearInterval(intervalId);
      }
    };
  }, [isStarting, isTerminating, setIsStarting, setSessions]);


  useEffect(() => {
    (async () => {
      if (collectionProps.selectedItems && collectionProps.selectedItems.length > 0) {
        setSelectedSession(collectionProps.selectedItems[0]);
      } else {
        setSelectedSession(undefined);
      }
    })();
  }, [collectionProps.selectedItems]);


  const startSession = (event: CustomEvent<ButtonDropdownProps.ItemClickDetails>) => {
    systemApi.startSession(event.detail.id);
    setIsStarting(true);
  };

  const copyConnectionString = (instanceId: string) => {
    if (navigator && navigator.clipboard && navigator.clipboard.writeText) {
      const str = `${gatewayEndpoint}?authToken=${jwtToken}#${instanceId}`;
      return navigator.clipboard.writeText(str);
    }
  };

  const downloadConnectionFile = (instanceId: string) => {
    const file_link = document.createElement('a');
    const file_content = `
[connect]
host=${gatewayEndpoint}
port=${gatewayPort}
sessionid=${instanceId}
authtoken=${jwtToken}
user=${user.username}
weburlpath=

[version]
format=1.0
`;
    const file_blob =  new Blob([file_content], {type: 'text/plain' });
    file_link.href = URL.createObjectURL(file_blob);
    file_link.download = 'connection.dcv';
    file_link.click();
  }

  const confirmQuestion = async (session: SessionType) => {
    setQuestionVisible(false);
    terminate(session);
  }

  const terminate = async (session: SessionType) => {
      setIsTerminating(true);

      try {
        await systemApi.terminateSession(session.sessionId);
      } catch (error) {
        console.error(error);
        alert(I18n.get("Terminate session error"));

        setIsTerminating(false);
      }
  };

  const performAction = (code: string, session: SessionType) => {
    if (!session) {
      console.warn('No session selected');
      return;
    }

    switch (code) {
      case 'copy':
          copyConnectionString(session.instanceId);
          break;
      case 'terminate':
          setQuestionVisible(true);
          break;
      case 'file':
          downloadConnectionFile(session.instanceId);
          break;
      default:
          console.warn(`Unknown action ${code}`);
          break;
    }
  };

  const createButtonDisabled =
    !sessions ||
    (sessions.length > 0 &&
      sessions.every((s) => s.status != SessionStatus.Failed));

  return (
    <>
      <Navbar />
      <Modal
          onDismiss={() => setQuestionVisible(false)}
          visible={questionVisible}
          closeAriaLabel="Close modal"
          footer={
            <Box float="right">
              <SpaceBetween direction="horizontal" size="xs">
                <Button variant="link" onClick={() => setQuestionVisible(false)}>No</Button>
                <Button variant="primary" onClick={() => confirmQuestion(selectedSession!) }>Yes</Button>
              </SpaceBetween>
            </Box>
          }
          header="Please confirm"
      >
        { I18n.get("Do you want to terminate the session?") }
      </Modal>
      <AppLayout
        contentType="table"
        content={
          <Table
            {...collectionProps}
            header={
              <Header
                description={`${allocatedInstanceCount} ${I18n.get("pre-allocated instances available")}`}
                variant="awsui-h1-sticky"
                counter={sessions ? `(${sessions.length})` : ""}
                actions={
                  <SpaceBetween direction="horizontal" size="xs">
                    <ButtonDropdown
                      variant="normal"
                      items={[
                        {
                          text: I18n.get("Terminate"),
                          id: "terminate",
                          iconName: "close",
                          disabled: selectedSession?.status !== SessionStatus.Available
                        },
                        {
                          text: I18n.get("Copy connection string"),
                          id: "copy",
                          iconName: "copy",
                          disabled: selectedSession?.status !== SessionStatus.Available
                        },
                        {
                          text: I18n.get("Download connection file"),
                          id: "file",
                          iconName: "file",
                          disabled: selectedSession?.status !== SessionStatus.Available
                        },
                      ]}
                      disabled={ !selectedSession }
                      onItemClick={({ detail }) => performAction(detail.id, selectedSession!)}
                    >
                      Actions
                    </ButtonDropdown>
                     {isStarting ?
                        <Button
                          variant="primary"
                          loading
                          loadingText={I18n.get("Launching")}>
                          {I18n.get("Launching")}
                        </Button>
                      :
                         <ButtonDropdown
                             variant="primary"
                             items={templates}
                             disabled={createButtonDisabled}
                             onItemClick={startSession} >
                           {I18n.get("Launch")}
                         </ButtonDropdown>
                      }
                  </SpaceBetween>
                }
              >
                Sessions
              </Header>
            }
            variant="full-page"
            stickyHeader={true}
            columnDefinitions={COLUMN_DEFINITIONS}
            items={items}
            selectionType="single"
            loading={isLoading}
            visibleColumns={visibleColumns}
            empty={
            <>
              {I18n.get("No active sessions")}
            </>
            }
            pagination={
              <Pagination {...paginationProps} ariaLabels={PAGINATION_ARIA} />
            }
          />
        }
        headerSelector="navbar"
        navigationHide={true}
        toolsHide={true}
        breadcrumbs={
          <BreadcrumbGroup
            items={[
              { text: "NICE DCV Web Portal", href: "/" },
              { text: "Sessions", href: "#" },
            ]}
          />
        }
      />
    </>
  );
}

export default withAuthenticator(Home, {
  hideSignUp: true,
});
