<!--
  Copyright (C) 2025 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <div>
    <cv-grid fullWidth>
      <cv-row>
        <cv-column class="page-title">
          <h2>{{ $t("settings.title") }}</h2>
        </cv-column>
      </cv-row>
      <cv-row v-if="error.getConfiguration">
        <cv-column>
          <NsInlineNotification
            kind="error"
            :title="$t('action.get-configuration')"
            :description="error.getConfiguration"
            :showCloseButton="false"
          />
        </cv-column>
      </cv-row>
      <cv-row>
        <cv-column>
          <cv-tile light>
            <cv-form @submit.prevent="validateSetConfiguration">
              <NsTextInput
                v-model.trim="domain"
                :label="$t('settings.domain')"
                :invalid-message="error.realm"
                :disabled="loading.getConfiguration || loading.setConfiguration"
                light
                readonly
              />
              <NsTextInput
                v-model.trim="serverName"
                :label="$t('settings.file_server_name')"
                :invalid-message="error.hostname"
                :disabled="loading.getConfiguration || loading.setConfiguration"
                tooltipAlignment="start"
                tooltipDirection="right"
                maxlength="15"
                light
                readonly
              >
                <template #tooltip>
                  <div>{{ $t("settings.file_server_name_tooltip") }}</div>
                </template>
              </NsTextInput>
              <NsTextInput
                v-model.trim="serverAlias"
                :label="`${$t('settings.file_server_alias')} (${$t(
                  'common.optional'
                )})`"
                :invalid-message="error.nbalias"
                :disabled="loading.getConfiguration || loading.setConfiguration"
                tooltipAlignment="start"
                tooltipDirection="right"
                class="mg-bottom-lg"
                maxlength="15"
                ref="nbalias"
              >
                <template #tooltip>
                  <div>{{ $t("settings.file_server_alias_tooltip") }}</div>
                </template>
              </NsTextInput>
              <NsComboBox
                v-model="ipAddress"
                :title="$t('settings.file_server_ip_address')"
                :label="$t('welcome.choose_ip_address')"
                :invalid-message="error.ipaddress"
                :auto-filter="true"
                :auto-highlight="true"
                :options="ipAddresses"
                :disabled="loading.setConfiguration"
                :readonly="!ipAddressAlterable"
                :light="!ipAddressAlterable"
                tooltipAlignment="start"
                tooltipDirection="right"
                class="mg-bottom-6"
                ref="ipaddress"
              >
                <template #tooltip>
                  <div>{{ $t("settings.file_server_ip_address_tooltip") }}</div>
                </template>
              </NsComboBox>
              <NsInlineNotification
                v-if="error.setConfiguration"
                kind="error"
                :title="$t('action.set-configuration')"
                :description="error.setConfiguration"
                :showCloseButton="false"
              />
              <NsInlineNotification
                v-if="error.invalidCredentials"
                kind="error"
                :title="$t('error.incorrect_username_or_password')"
                :description="error.invalidCredentials"
                :showCloseButton="false"
              />
              <NsButton
                kind="primary"
                :icon="Save20"
                :loading="loading.setConfiguration"
                :disabled="loading.getConfiguration || loading.setConfiguration"
                >{{ $t("settings.save_settings") }}</NsButton
              >
            </cv-form>
          </cv-tile>
        </cv-column>
      </cv-row>
    </cv-grid>
    <!-- credentials modal -->
    <CredentialsModal
      :isShown="isShownCredentialsModal"
      @hide="isShownCredentialsModal = false"
      @enterCredentials="onEnterCredentials"
    />
  </div>
</template>

<script>
import to from "await-to-js";
import { mapState, mapActions } from "vuex";
import {
  QueryParamService,
  UtilService,
  TaskService,
  IconService,
  PageTitleService,
} from "@nethserver/ns8-ui-lib";
import CredentialsModal from "@/components/CredentialsModal.vue";

export default {
  name: "Settings",
  components: { CredentialsModal },
  mixins: [
    TaskService,
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
  ],
  pageTitle() {
    return this.$t("settings.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "settings",
      },
      urlCheckInterval: null,
      domain: "",
      serverName: "",
      serverAlias: "",
      ipAddress: "",
      credentialsRequired: false,
      ipAddressAlterable: false,
      isShownCredentialsModal: false,
      loading: {
        getConfiguration: false,
        setConfiguration: false,
      },
      error: {
        getConfiguration: "",
        setConfiguration: "",
        realm: "",
        adminuser: "",
        adminpass: "",
        hostname: "",
        nbalias: "",
        ipaddress: "",
        invalidCredentials: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName", "configuration"]),
    ipAddresses() {
      if (!this.configuration) {
        return [];
      }
      return this.configuration.ipaddress_list.map((ip) => {
        return {
          name: ip.ipaddress,
          label: `${ip.ipaddress} - ${ip.label}`,
          value: ip.ipaddress,
        };
      });
    },
  },
  watch: {
    configuration: function (config) {
      // this is needed in case the wizard is shown on the settings page
      this.updateFields(config);
    },
  },
  beforeRouteEnter(to, from, next) {
    next((vm) => {
      vm.watchQueryData(vm);
      vm.urlCheckInterval = vm.initUrlBindingForApp(vm, vm.q.page);
    });
  },
  beforeRouteLeave(to, from, next) {
    clearInterval(this.urlCheckInterval);
    next();
  },
  created() {
    this.getConfiguration();
  },
  methods: {
    ...mapActions(["setConfigurationInStore"]),
    updateFields(config) {
      this.domain = config.domain || "";
      this.serverName = config.hostname || "";
      this.serverAlias = config.nbalias || "";
      this.credentialsRequired = config.credentials_required || false;
      this.ipAddressAlterable = config.ipaddress_alterable || false;

      // ensure combobox options are loaded before setting the value
      this.$nextTick(() => {
        this.ipAddress = config.ipaddress || "";
      });
    },
    async getConfiguration() {
      this.loading.getConfiguration = true;
      this.error.getConfiguration = "";
      const taskAction = "get-configuration";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getConfigurationAborted
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getConfigurationCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getConfiguration = this.getErrorMessage(err);
        this.loading.getConfiguration = false;
        return;
      }
    },
    getConfigurationAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getConfiguration = this.$t("error.generic_error");
      this.loading.getConfiguration = false;
    },
    getConfigurationCompleted(taskContext, taskResult) {
      this.loading.getConfiguration = false;
      const config = taskResult.output;
      this.setConfigurationInStore(config);
      this.updateFields(config);
    },
    validateSetConfiguration() {
      this.clearErrors(this);
      let isValidationOk = true;

      // alias

      // according to set-configuration schema:
      const aliasRegex = /^([a-zA-Z][-a-zA-Z0-9]*)?$/;

      if (!aliasRegex.test(this.serverAlias)) {
        this.error.nbalias = this.$t("error.nbalias_pattern");

        if (isValidationOk) {
          this.focusElement("nbalias");
          isValidationOk = false;
        }
      }

      // ip address

      if (!this.ipAddress) {
        this.error.ipaddress = this.$t("common.required");
        isValidationOk = false;
      }

      if (!isValidationOk) {
        // there are validation errors
        return;
      } else {
        // validation ok
        if (this.credentialsRequired) {
          this.isShownCredentialsModal = true;
        } else {
          this.setConfiguration();
        }
      }
    },
    onEnterCredentials(credentials) {
      this.setConfiguration(credentials.username, credentials.password);
    },
    setConfigurationValidationFailed(validationErrors) {
      this.loading.setConfiguration = false;

      for (const validationError of validationErrors) {
        const field = validationError.parameter;

        if (field !== "(root)") {
          if (validationError.error == "invalid_credentials") {
            // user entered wrong credentials in the modal
            this.error.invalidCredentials = this.$t(
              "settings.invalid_credentials_description"
            );
          } else {
            // set i18n error message
            this.error[field] = this.getI18nStringWithFallback(
              "settings." + validationError.error,
              "error." + validationError.error
            );
          }
        }
      }
    },
    async setConfiguration(username, password) {
      this.loading.setConfiguration = true;
      const taskAction = "set-configuration";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.setConfigurationAborted
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.setConfigurationValidationFailed
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.setConfigurationCompleted
      );

      const payload = {
        ipaddress: this.ipAddress,
        nbalias: this.serverAlias,
      };

      if (this.credentialsRequired) {
        payload.adminuser = username;
        payload.adminpass = password;
      }

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: payload,
          extra: {
            title: this.$t("settings.configure_instance", {
              instance: this.instanceName,
            }),
            description: this.$t("common.processing"),
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.setConfiguration = this.getErrorMessage(err);
        this.loading.setConfiguration = false;
        return;
      }
    },
    setConfigurationAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.setConfiguration = this.$t("error.generic_error");
      this.loading.setConfiguration = false;
    },
    setConfigurationCompleted() {
      this.loading.setConfiguration = false;

      // reload configuration
      this.getConfiguration();
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
</style>
