/**
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 */
import { Route, Routes } from "react-router-dom";
import Home from "./pages/home";
import AdminHome from "./pages/admin/home";
import NotFound from "./pages/not-found";
import * as React from "react";

const Router = () => (
<Routes>
    <Route path="/" element={<Home />} />
    <Route path="/admin" element={<AdminHome />} />
    <Route path="*" element={<NotFound />} />
</Routes>
);

export default Router;