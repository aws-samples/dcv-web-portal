/**
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 */
import * as React from "react";
import { useState, useEffect } from "react";
import { withAuthenticator } from "@aws-amplify/ui-react";
import { useNavigate } from "react-router-dom";
import { useCollection } from '@cloudscape-design/collection-hooks';
import { I18n } from "@aws-amplify/core";
import { useSplitPanel } from './split-panel';
import { PAGINATION_ARIA, SPLIT_PANEL_I18NSTRINGS } from '../../common/aria-labels';
import {
  systemApi,
  TemplateType,
  TemplateVersionType,
  TemplateDataType,
} from "../../common";
import { AppLayout, Box, BreadcrumbGroup, Button, Header, Modal, Pagination, SpaceBetween, SplitPanel, StatusIndicator, Table } from "@cloudscape-design/components";
import Navbar from "../../components/navbar";

type HomeProps = React.PropsWithChildren<{
  user: {
    signInUserSession: {
      accessToken: {
        payload: [];
      };
    };
  };
}>;

const COLUMN_DEFINITIONS_TEMPLATES = [
  {
    id: 'name',
    header: I18n.get('Template Name'),
    cell: item => item.name,
  },
  {
    id: 'id',
    header: I18n.get('Template Id'),
    cell: item => item.templateId,
  },
  {
    id: 'defaultVersion',
    header: I18n.get('Default version'),
    cell: item => item.defaultVersion,
  },
  {
    id: 'latestVersion',
    header: I18n.get('Latest version'),
    cell: item => item.latestVersion,
  },
];

const COLUMN_DEFINITIONS_VERSIONS = [
  {
    id: 'version',
    header: 'Version',
    cell: item => item.version,
  },
  {
    id: 'state',
    header: 'Activated',
    cell: item => (
      <>
        <StatusIndicator type={item.default ? 'success' : 'stopped'}>&nbsp;{item.default ? 'Yes' : 'No'}</StatusIndicator>
      </>
    ),
  },
  {
    id: 'date',
    header: 'Creation date',
    cell: item => item.createTime,
  },
  {
    id: 'image',
    header: 'Image Id',
    cell: item => item.imageId,
  },
];


function Home(props: HomeProps) {
  const { user } = props;
  const navigate = useNavigate();
  const [questionVisible, setQuestionVisible] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [isLoadingDetails, setIsLoadingDetails] = useState(false);
  const [questionText, setQuestionText] = useState("");
  const [questionCode, setQuestionCode] = useState("");

  const [templates, setTemplates] = useState<TemplateType[]>([]);
  const [templateData, setTemplateData] = useState<TemplateDataType>();
  const [versions, setVersions] = useState<TemplateVersionType[]>([]);
  const [selectedVersion, setSelectedVersion] = useState<TemplateVersionType>();

  const {
    items: templateItems,
    collectionProps: templateCollectionProps,
    paginationProps: templatePaginationProps
  } = useCollection(templates, {
    pagination: { pageSize: 20},
    selection: {}
  });

  const {
    items: versionItems,
    paginationProps: versionPaginationProps
  } = useCollection(versions, {
    pagination: { pageSize: 20},
    selection: {}
  });

  const confirmQuestion = async (code:string) => {
    setQuestionVisible(false);
    setQuestionCode("");
    setQuestionText("");
    if (code === "activation") {
      setIsLoadingDetails(true);
      await systemApi.setTemplateVersion(selectedVersion!.templateId, selectedVersion!.version);
      await loadTemplateData(selectedVersion!.templateId);
      setIsLoadingDetails(false);
    } else if (code === "start") {
      await systemApi.startInstance(
        selectedVersion!.name,
        selectedVersion!.version.toString()
      );
      navigate("/");
    } else {
      console.warn(`Unknown code ${code}`);
    }
  }

  const makeActive = async (
    version: TemplateVersionType
  ) => {
    const str = I18n.get('Do you want to make version "{0}" active?').replace(
      "{0}",
      version.version.toString()
    );
    setQuestionCode("activation");
    setQuestionText(str);
    setQuestionVisible(true);
  };

const start = async (version: TemplateVersionType) => {
  const str = I18n.get('Do you want to start VM version "{0}"?').replace(
    "{0}",
    version.version.toString()
  );
  setQuestionCode("start");
  setQuestionText(str);
  setQuestionVisible(true);
};

  const { splitPanelOpen, onSplitPanelToggle, splitPanelSize, onSplitPanelResize } = useSplitPanel(
    templateCollectionProps.selectedItems
  );

  const groups =
    user.signInUserSession.accessToken.payload["cognito:groups"] || [];
  const isAdmin = groups.includes("admin");

  const loadTemplateData = async (templateId: string) => {
    if (!templateId) {
      return;
    }
    setIsLoadingDetails(true);
    try {
      const data = await systemApi.getTemplate(templateId);
      setTemplateData(data);
      setVersions(data.versions);
      setSelectedVersion(undefined);
    } catch (error) {
      console.error(error);
      alert(I18n.get("Loading error"));
    }
    setIsLoadingDetails(false);
  };

  useEffect(() => {
    (async () => {
      if (templateCollectionProps.selectedItems && templateCollectionProps.selectedItems.length > 0) {
        const selectedTemplate = templateCollectionProps.selectedItems[0];
        loadTemplateData(selectedTemplate.templateId);
      }
    })();
  }, [templateCollectionProps.selectedItems]);

  useEffect(() => {
    (async () => {
      if (!isAdmin) {
        navigate("/");
        return;
      }
      setIsLoading(true);

      try {
        const { templates } = await systemApi.getTemplates();
        setTemplates(templates);
      } catch (error) {
        console.error(error);
        alert(I18n.get("Loading error"));
      }

      setIsLoading(false);
    })();
  }, []);

  if (!isAdmin) {
    return <></>;
  }

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
              <Button variant="primary" onClick={() => confirmQuestion(questionCode) }>Yes</Button>
            </SpaceBetween>
          </Box>
        }
        header="Please confirm"
      >
        { questionText }
      </Modal>
      <AppLayout
        contentType="table"
        content={
          <Table
            {...templateCollectionProps}
            header={
              <Header
                variant="awsui-h1-sticky"
                counter={`(${templates.length})`}
              >Templates</Header>
            }
            variant="full-page"
            stickyHeader={true}
            columnDefinitions={COLUMN_DEFINITIONS_TEMPLATES}
            items={templateItems}
            selectionType="single"
            loading={isLoading}
            pagination={<Pagination {...templatePaginationProps} ariaLabels={PAGINATION_ARIA} />}
           />
        }
        splitPanelOpen={splitPanelOpen}
        onSplitPanelToggle={onSplitPanelToggle}
        splitPanelSize={splitPanelSize}
        onSplitPanelResize={onSplitPanelResize}
        splitPanel={
          <SplitPanel
            header={
              isLoadingDetails? "1 template selected" :
              templateData? templateData.template.name :
              "0 template selected"
            } i18nStrings={SPLIT_PANEL_I18NSTRINGS}
            children={
              isLoadingDetails? (
                <StatusIndicator type="loading">
                Loading
              </StatusIndicator>
              ) : versions? (
                <Table
                  header={
                    <Header variant="h3" counter={`(${versions.length || "?"})`} actions={
                      <SpaceBetween size='s' direction="horizontal">
                        <Button onClick={() => makeActive(selectedVersion!)} disabled={!selectedVersion || selectedVersion?.default}>Activate</Button>
                        <Button onClick={() => start(selectedVersion!)} disabled={!selectedVersion}>Start</Button>
                      </SpaceBetween>
                    } >
                      Versions available
                    </Header>
                  }
                  onSelectionChange={({detail}) => setSelectedVersion(detail.selectedItems[0])}
                  selectedItems={[selectedVersion]}
                  columnDefinitions={COLUMN_DEFINITIONS_VERSIONS}
                  items={versionItems}
                  loading={isLoadingDetails}
                  pagination={<Pagination {...versionPaginationProps} ariaLabels={PAGINATION_ARIA} />}
                  selectionType="single"
                  variant="embedded"
                ></Table>
              ) : "Select a template to see its details."} />
        }
        headerSelector="navbar"
        navigationHide={true}
        toolsHide={true}
        breadcrumbs={<BreadcrumbGroup
          items={[
            { text: 'Admin', href: '/admin' },
            { text: 'Templates', href: '#' },
          ]} />}
      />
    </>
  );
}

export default withAuthenticator(Home, {
  hideSignUp: true,
});
