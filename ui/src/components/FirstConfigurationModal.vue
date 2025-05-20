<!--
  Copyright (C) 2025 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <NsWizard
    size="default"
    :visible="isShown"
    :cancelLabel="core.$t('common.cancel')"
    :previousLabel="core.$t('common.previous')"
    :nextLabel="
      isLastStep ? $t('welcome.create_file_server') : core.$t('common.next')
    "
    :isPreviousDisabled="isFirstStep || loading.configureModule"
    :isNextDisabled="isNextButtonDisabled"
    :isNextLoading="loading.configureModule"
    :isCancelDisabled="true"
    @modal-shown="onModalShown"
    @previousStep="previousStep"
    @nextStep="nextStep"
    auto-hide-off
  >
    <template slot="title">{{ $t("welcome.title") }}</template>
    <template slot="content">
      <cv-form>
        <NsInlineNotification
          v-if="error.listUserDomains"
          kind="error"
          :title="$t('action.list-user-domains')"
          :description="error.listUserDomains"
          :showCloseButton="false"
        />
        <template v-if="step == 'domain'">
          <cv-skeleton-text
            v-if="loading.listUserDomains"
            :paragraph="true"
            :line-count="4"
            heading
          ></cv-skeleton-text>
          <!-- no user domain configured -->
          <template v-else-if="!adDomains.length">
            <NsEmptyState :title="$t('welcome.no_domain_configured')">
              <template #description>
                <div>
                  {{ $t("welcome.no_domain_configured_description") }}
                </div>
                <NsButton
                  kind="ghost"
                  :icon="Events20"
                  @click="goToDomainsAndUsers"
                  class="empty-state-button"
                >
                  {{ $t("welcome.go_to_domains_and_users") }}
                </NsButton>
              </template>
            </NsEmptyState>
          </template>
          <!-- there are user domains configured -->
          <template v-else>
            <div class="mg-bottom-lg">
              <div>{{ $t("welcome.step_domain_description") }}</div>
            </div>
            <NsComboBox
              v-model="adDomain"
              :title="$t('settings.domain')"
              :label="
                loading.listUserDomains
                  ? $t('common.loading')
                  : $t('welcome.choose_domain')
              "
              :invalid-message="error.realm"
              :auto-filter="true"
              :auto-highlight="true"
              :options="adDomains"
              :disabled="loading.listUserDomains"
              light
              class="mg-bottom-6"
              ref="realm"
            />
          </template>
        </template>
        <template v-else-if="step == 'credentials'">
          <div class="mg-bottom-lg">
            {{ $t("welcome.step_credentials_description") }}
          </div>
          <NsTextInput
            v-model.trim="username"
            :label="$t('settings.ad_admin_username')"
            :invalid-message="error.adminuser"
            light
            autocomplete="username"
            class="mg-bottom-lg"
            ref="adminuser"
          />
          <NsTextInput
            v-model="password"
            type="password"
            :label="$t('settings.ad_admin_password')"
            :invalid-message="error.adminpass"
            light
            autocomplete="current-password"
            class="mg-bottom-3"
            ref="adminpass"
          />
        </template>
        <template v-else-if="step == 'settings'">
          <div>
            <div class="mg-bottom-lg">
              {{ $t("welcome.step_settings_description") }}
            </div>
            <NsTextInput
              v-model.trim="serverName"
              :label="$t('settings.file_server_name')"
              :invalid-message="error.hostname"
              :disabled="loading.configureModule"
              light
              tooltipAlignment="start"
              tooltipDirection="right"
              class="mg-bottom-lg"
              maxlength="15"
              ref="hostname"
            >
              <template #tooltip>
                <div>{{ $t("welcome.file_server_name_tooltip") }}</div>
              </template>
            </NsTextInput>
            <NsTextInput
              v-model.trim="serverAlias"
              :label="`${$t('settings.file_server_alias')} (${$t(
                'common.optional'
              )})`"
              :invalid-message="error.nbalias"
              :disabled="loading.configureModule"
              light
              tooltipAlignment="start"
              tooltipDirection="right"
              class="mg-bottom-lg"
              maxlength="15"
              ref="nbalias"
            >
              <template #tooltip>
                <div>{{ $t("welcome.file_server_alias_tooltip") }}</div>
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
              :disabled="loading.configureModule"
              light
              class="mg-bottom-6"
              ref="ipaddress"
            >
              <template #tooltip>
                <div>{{ $t("welcome.file_server_ip_address_tooltip") }}</div>
              </template>
            </NsComboBox>
            <NsInlineNotification
              v-if="error.configureModule"
              kind="error"
              :title="$t('action.configure-module')"
              :description="error.configureModule"
              :showCloseButton="false"
            />
          </div>
        </template>
      </cv-form>
    </template>
  </NsWizard>
</template>

<script>
import { UtilService, TaskService, IconService } from "@nethserver/ns8-ui-lib";
import to from "await-to-js";
import { mapState, mapActions } from "vuex";

export default {
  name: "FirstConfigurationModal",
  mixins: [UtilService, TaskService, IconService],
  props: {
    isShown: {
      type: Boolean,
      default: true,
    },
  },
  data() {
    return {
      step: "",
      adDomain: "",
      adDomains: [],
      username: "",
      password: "",
      serverName: "",
      serverAlias: "",
      ipAddress: "",
      loading: {
        configureModule: false,
        listUserDomains: true,
        getConfiguration: false,
      },
      error: {
        configureModule: "",
        listUserDomains: "",
        getConfiguration: "",
        realm: "",
        adminuser: "",
        adminpass: "",
        hostname: "",
        nbalias: "",
        ipaddress: "",
      },
    };
  },
  computed: {
    ...mapState(["core", "instanceName", "configuration"]),
    stepIndex() {
      return this.steps.indexOf(this.step);
    },
    isFirstStep() {
      return this.stepIndex == 0;
    },
    isLastStep() {
      return this.stepIndex == this.steps.length - 1;
    },
    isNextButtonDisabled() {
      return (
        this.loading.listUserDomains ||
        !this.adDomains.length ||
        this.loading.configureModule ||
        (this.step == "domain" && !this.adDomain) ||
        (this.step == "credentials" && (!this.username || !this.password)) ||
        (this.step == "settings" && (!this.serverName || !this.ipAddress))
      );
    },
    steps() {
      if (!this.configuration) {
        return [];
      }

      return this.configuration.domain
        ? ["credentials", "settings"]
        : ["domain", "credentials", "settings"];
    },
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
    step: function () {
      if (this.step == "credentials") {
        this.focusElement("adminuser");
      } else if (this.step == "settings") {
        this.focusElement("hostname");

        // select the first ip address if there is only one
        this.$nextTick(() => {
          if (!this.ipAddress && this.ipAddresses.length == 1) {
            this.ipAddress = this.ipAddresses[0].value;
          }
        });
      }
    },
  },
  methods: {
    ...mapActions(["setAppConfiguredInStore"]),
    onModalShown() {
      // show first step
      this.step = this.steps[0];
      this.listUserDomains();
    },
    nextStep() {
      if (this.isNextButtonDisabled) {
        return;
      }

      if (this.isLastStep) {
        this.configureModule();
      } else {
        this.step = this.steps[this.stepIndex + 1];
      }
    },
    previousStep() {
      if (!this.isFirstStep) {
        this.step = this.steps[this.stepIndex - 1];
      }
    },
    async listUserDomains() {
      this.loading.listUserDomains = true;
      this.error.listUserDomains = "";
      const taskAction = "list-user-domains";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.listUserDomainsAborted
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.listUserDomainsCompleted
      );

      const res = await to(
        this.createClusterTaskForApp({
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
        this.error.listUserDomains = this.getErrorMessage(err);
        this.loading.listUserDomains = false;
        return;
      }
    },
    listUserDomainsAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.listUserDomains = this.$t("error.generic_error");
      this.loading.listUserDomains = false;
    },
    listUserDomainsCompleted(taskContext, taskResult) {
      this.adDomains = taskResult.output.domains
        .filter((d) => {
          return d.schema == "ad";
        })
        .map((d) => {
          return {
            name: d.name,
            label: d.name,
            value: d.name,
          };
        });

      // ensure combobox options are loaded before setting the value
      this.$nextTick(() => {
        if (this.adDomains.length == 1) {
          this.adDomain = this.adDomains[0].value;
        }
      });

      this.loading.listUserDomains = false;
    },
    async configureModule() {
      this.loading.configureModule = true;
      this.clearErrors();
      this.error.configureModule = "";
      const taskAction = "configure-module";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.configureModuleAborted
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.configureModuleValidationFailed
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.configureModuleCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            provision: "join-member",
            adminuser: this.username,
            adminpass: this.password,
            realm: this.configuration.domain || this.adDomain,
            hostname: this.serverName,
            ipaddress: this.ipAddress,
            nbalias: this.serverAlias,
          },
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
        this.error.configureModule = this.getErrorMessage(err);
        this.loading.configureModule = false;
        return;
      }
    },
    configureModuleAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.configureModule = this.$t("error.generic_error");
      this.loading.configureModule = false;
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;
      let focusAlreadySet = false;

      for (const validationError of validationErrors) {
        const field = validationError.field;

        if (field !== "(root)") {
          if (validationError.error == "invalid_credentials") {
            this.error.adminuser = this.$t(
              "error.incorrect_username_or_password"
            );
            this.error.adminpass = this.$t(
              "error.incorrect_username_or_password"
            );
          } else {
            // set i18n error message
            this.error[field] = this.getI18nStringWithFallback(
              "welcome." + validationError.error,
              "error." + validationError.error
            );
          }

          if (!focusAlreadySet && field !== "ipaddress") {
            if (field == "realm") {
              this.step = "domain";
            } else if (["adminuser", "adminpass"].includes(field)) {
              this.step = "credentials";
            }
            this.focusElement(field);
            focusAlreadySet = true;
          }
        }
      }
    },
    configureModuleCompleted() {
      // close first configuration wizard
      this.$emit("close");

      this.$nextTick(() => {
        // reload configuration
        this.$emit("configured");
      });
      this.loading.configureModule = false;
    },
    goToDomainsAndUsers() {
      this.core.$router.push("/domains");
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";

.mg-bottom-3 {
  margin-bottom: 3rem;
}

.mg-bottom-6 {
  margin-bottom: 6rem;
}
</style>
