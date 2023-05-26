/**
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 */

import { useState, useEffect } from 'react';

export const useSplitPanel = selectedItems => {
    const [splitPanelSize, setSplitPanelSize] = useState(400);
    const [splitPanelOpen, setSplitPanelOpen] = useState(false);
    const [hasManuallyClosedOnce, setHasManuallyClosedOnce] = useState(false);

    const onSplitPanelResize = ({ detail: { size } }) => {
      setSplitPanelSize(size);
    };

    const onSplitPanelToggle = ({ detail: { open } }) => {
      setSplitPanelOpen(open);

      if (!open) {
        setHasManuallyClosedOnce(true);
      }
    };

    useEffect(() => {
      if (selectedItems && selectedItems.length && !hasManuallyClosedOnce) {
        setSplitPanelOpen(true);
      }
    }, [selectedItems, hasManuallyClosedOnce]);

    return {
      splitPanelOpen,
      onSplitPanelToggle,
      splitPanelSize,
      onSplitPanelResize,
    };
  };
