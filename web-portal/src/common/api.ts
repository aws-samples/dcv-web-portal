/**
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 */
import { API } from "aws-amplify";

const API_NAME = "SessionsAPI";

export type SessionType = {
  sessionId: string;
  userId: string;
  instanceId: string;
  status: SessionStatus;
  details: string;
  launchTemplateName: string;
  launchTemplateVersion: string;
};

export type TemplateType = {
  templateId: string;
  name: string;
  createdAt: string;
  defaultVersion: number;
  latestVersion: number;
};

export type TemplateVersionType = {
  templateId: string;
  name: string;
  createTime: string;
  version: number;
  imageId: string;
  default: boolean;
};

export type TemplateDataType = {
  template: TemplateType;
  versions: TemplateVersionType[];
};

export enum SessionStatus {
  Pending = "PENDING",
  Launching = "LAUNCHING",
  Finalising = "FINALISING",
  Failed = "FAILED",
  Available = "AVAILABLE",
  Terminating = "TERMINATING",
  FailedTerminating = "FAILED_TERMINATING",
}

class SystemApi {
  async listSessions(): Promise<{ sessions: SessionType[] }> {
    const response = await API.get(API_NAME, "/sessions", {});

    return response;
  }

  async startSession(
    launchTemplateName: string,
    launchTemplateVersion = "$Default"
  ) {
    const apiOptions: { [key: string]: any } = {};
    apiOptions["headers"] = {
      "Content-Type": "application/json",
    };

    const body = { launchTemplateVersion, launchTemplateName };
    apiOptions["body"] = body;

    const response = await API.put(API_NAME, "/sessions", apiOptions);

    return response;
  }

  async startInstance(
      launchTemplateName: string,
      launchTemplateVersion = "$Default"
  ) {
    const apiOptions: { [key: string]: any } = {};
    apiOptions["headers"] = {
      "Content-Type": "application/json",
    };

    const body = { launchTemplateVersion, launchTemplateName };
    apiOptions["body"] = body;

    const response = await API.put(API_NAME, "/instances", apiOptions);

    return response;
  }

  async terminateSession(sessionId: string) {
    const apiOptions: { [key: string]: any } = {};
    apiOptions["headers"] = {
      "Content-Type": "application/json",
    };

    const response = await API.del(
      API_NAME,
      `/sessions/${sessionId}`,
      apiOptions
    );

    return response;
  }

  async getAllocatedInstanceCount(): Promise<number> {
    const { count } = await API.get(API_NAME, "/instances", {});

    return count;
  }

  async getTemplates(): Promise<{ templates: TemplateType[] }> {
    const response = await API.get(API_NAME, "/templates", {});

    return response;
  }

  async getTemplate(
    templateId: string
  ): Promise<{ template: TemplateType; versions: TemplateVersionType[] }> {
    const response = await API.get(API_NAME, `/templates/${templateId}`, {});

    return response;
  }

  async setTemplateVersion(templateId: string, version: number): Promise<any> {
    const apiOptions: { [key: string]: any } = {};

    const token = uuid4();
    const body = { version, token };
    apiOptions["body"] = body;

    const response = await API.post(
      API_NAME,
      `/templates/${templateId}`,
      apiOptions
    );

    return response;
  }
}

export function getSessionStatusText(status: SessionStatus) {
  let txt = status.toString();

  if (status === SessionStatus.Pending) txt = "En attente";
  if (status === SessionStatus.Launching) txt = "Lancement";
  if (status === SessionStatus.Finalising) txt = "Finalisation";
  if (status === SessionStatus.Failed) txt = "Échec";
  if (status === SessionStatus.Available) txt = "Disponible";
  if (status === SessionStatus.Terminating) txt = "Arrêt";
  if (status === SessionStatus.FailedTerminating)
    txt = "Échec de la terminaison";

  return txt;
}

export function getSessionStatusETA(status: SessionStatus) {
  let txt = "";

  if (status === SessionStatus.Pending) txt = "~15m";
  if (status === SessionStatus.Launching) txt = "~15m";
  if (status === SessionStatus.Finalising) txt = "~10s";

  return txt.length > 0 ? `(${txt})` : "";
}

function uuid4() {
  const array = new Uint8Array(16);
  crypto.getRandomValues(array);

  // manipulate 9th byte
  array[8] &= 0b00111111; // clear first two bits
  array[8] |= 0b10000000; // set first two bits to 10

  // manipulate 7th byte
  array[6] &= 0b00001111; // clear first four bits
  array[6] |= 0b01000000; // set first four bits to 0100

  const pattern = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
  let idx = 0;

  return pattern.replace(
    /XX/g,
    () => array[idx++].toString(16).padStart(2, "0") // padStart ensures leading zero, if needed
  );
}

export const systemApi = new SystemApi();
