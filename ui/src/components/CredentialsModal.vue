<!--
  Copyright (C) 2025 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <NsModal
    size="small"
    :visible="isShown"
    :primary-button-disabled="!username || !password"
    @modal-shown="onModalShown"
    @modal-hidden="hideModal"
    @primary-click="emitCredentials"
    class="no-pad-modal"
  >
    <template slot="title">{{ $t("settings.save_settings") }}</template>
    <template slot="content">
      <p class="mg-bottom-lg">
        {{ $t("settings.credentials_required_description") }}
      </p>
      <cv-form @submit.prevent="emitCredentials">
        <!-- username -->
        <NsTextInput
          v-model.trim="username"
          :label="$t('settings.ad_admin_username')"
          light
          autocomplete="username"
          data-modal-primary-focus
        />
        <!-- password -->
        <NsTextInput
          v-model="password"
          type="password"
          :label="$t('settings.ad_admin_password')"
          light
          autocomplete="current-password"
          class="mg-bottom-3"
        />
      </cv-form>
    </template>
    <template slot="secondary-button">{{ $t("common.cancel") }}</template>
    <template slot="primary-button">{{ $t("common.save") }}</template>
  </NsModal>
</template>

<script>
import { UtilService, TaskService, IconService } from "@nethserver/ns8-ui-lib";

export default {
  name: "CredentialsModal",
  mixins: [UtilService, TaskService, IconService],
  props: {
    isShown: Boolean,
  },
  data() {
    return {
      username: "",
      password: "",
    };
  },
  methods: {
    onModalShown() {
      this.username = "";
      this.password = "";
    },
    hideModal() {
      this.$emit("hide");
      this.username = "";
      this.password = "";
    },
    emitCredentials() {
      this.$emit("enterCredentials", {
        username: this.username,
        password: this.password,
      });
      this.hideModal();
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";

.mg-bottom-3 {
  margin-bottom: 3rem;
}
</style>
