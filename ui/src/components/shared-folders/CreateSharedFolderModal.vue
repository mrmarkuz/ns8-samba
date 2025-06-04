<!--
  Copyright (C) 2023 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <NsModal
    size="default"
    :visible="isShown"
    :primary-button-disabled="loading.addShare"
    :isLoading="loading.addShare"
    @modal-hidden="onModalHidden"
    @primary-click="addShare"
    class="no-pad-modal"
  >
    <template slot="title">{{ $t("shares.create_shared_folder") }}</template>
    <template slot="content">
      <cv-form @submit.prevent="addShare">
        <!-- name -->
        <NsTextInput
          v-model.trim="name"
          :label="$t('shares.name')"
          :invalid-message="error.name"
          :disabled="loading.addShare"
          data-modal-primary-focus
          ref="name"
        />
        <!-- description -->
        <NsTextInput
          v-model.trim="description"
          :label="
            $t('shares.description') + ' (' + core.$t('common.optional') + ')'
          "
          :invalid-message="error.description"
          :disabled="loading.addShare"
          ref="description"
        />
        <!-- main group -->
        <NsComboBox
          v-model="group"
          :label="
            loading.listDomainGroups
              ? core.$t('common.loading')
              : core.$t('common.choose')
          "
          :options="groupsForComboBox"
          auto-highlight
          :title="$t('shares.main_group')"
          :invalid-message="error.group"
          :disabled="loading.addShare || loading.listDomainGroups"
          tooltipAlignment="start"
          tooltipDirection="bottom"
          light
          ref="group"
        >
          <template slot="tooltip">
            <div>{{ $t("shares.main_group_tooltip") }}</div>
          </template>
        </NsComboBox>
        <!-- initial permissions -->
        <label class="bx--label">
          {{ $t("shares.initial_permissions") }}
        </label>
        <PermissionsSelector
          :permissions="permissions"
          :disabled="loading.addShare"
          :validationErrorMessage="error.permissions"
          @selected="onPermissionsSelected"
        />
        <!-- need to wrap error notification inside a div: custom elements like NsInlineNotification don't have scrollIntoView() function -->
        <div ref="addShareError">
          <NsInlineNotification
            v-if="error.addShare"
            kind="error"
            :title="$t('shares.create_shared_folder')"
            :description="error.addShare"
            :showCloseButton="false"
          />
        </div>
        <!-- advanced options -->
        <cv-accordion ref="accordion" class="mg-top-lg">
          <cv-accordion-item :open="toggleAccordion[0]">
            <template slot="title">{{ core.$t("common.advanced") }}</template>
            <template slot="content">
              <NsToggle
                value="enable_audit"
                :label="$t('shares.enable_audit')"
                v-model="enable_audit"
                :form-item="true"
                :disabled="loading.addShare"
                :error-message="error.enable_audit"
                class="mg-bottom"
                tooltipDirection="top"
                tooltipAlignment="start"
              >
                <template slot="tooltip">
                  <div>
                    {{ $t("shares.enable_audit_tooltip") }}
                  </div>
                </template>
                <template slot="text-left">{{
                  $t("common.disabled")
                }}</template>
                <template slot="text-right">{{
                  $t("common.enabled")
                }}</template>
              </NsToggle>
              <NsToggle
                v-if="enable_audit"
                value="log_failed_events"
                :label="$t('shares.log_failed_events')"
                v-model="log_failed_events"
                :form-item="true"
                :disabled="loading.addShare"
                :error-message="error.log_failed_events"
                class="mg-bottom mg-left-md"
              >
                <template slot="text-left">{{
                  $t("common.disabled")
                }}</template>
                <template slot="text-right">{{
                  $t("common.enabled")
                }}</template>
              </NsToggle>
              <NsToggle
                value="browseable"
                :label="$t('shares.browseable')"
                v-model="browseable"
                :form-item="true"
                :disabled="loading.addShare"
                :error-message="error.browseable"
                class="mg-bottom"
                tooltipDirection="top"
                tooltipAlignment="start"
              >
                <template slot="tooltip">
                  <div>
                    {{ $t("shares.browseable_tooltip") }}
                  </div>
                </template>
                <template slot="text-left">{{
                  $t("common.disabled")
                }}</template>
                <template slot="text-right">{{
                  $t("common.enabled")
                }}</template>
              </NsToggle>
              <NsToggle
                value="enable_recycle"
                :label="$t('shares.enable_recycle')"
                v-model="enable_recycle"
                :form-item="true"
                :disabled="loading.addShare"
                :error-message="error.enable_recycle"
                class="mg-bottom"
                tooltipDirection="top"
                tooltipAlignment="start"
              >
                <template slot="tooltip">
                  <div>
                    {{ $t("shares.enable_recycle_tooltip") }}
                  </div>
                </template>
                <template slot="text-left">{{
                  $t("common.disabled")
                }}</template>
                <template slot="text-right">{{
                  $t("common.enabled")
                }}</template>
              </NsToggle>
              <div class="mg-left-md">
                <template v-if="enable_recycle">
                  <label class="bx--label">
                    {{ $t("shares.retention") }}
                  </label>
                  <cv-radio-group vertical>
                    <cv-radio-button
                      v-model="recycle_retention_radio"
                      value="limited"
                      :label="$t('shares.limited')"
                      ref="recycle_retention_radio_limited"
                      :disabled="loading.addShare"
                      checked
                    ></cv-radio-button>
                    <cv-radio-button
                      v-model="recycle_retention_radio"
                      value="unlimited"
                      :label="$t('shares.unlimited')"
                      :disabled="loading.addShare"
                      ref="recycle_retention_radio_unlimited"
                    ></cv-radio-button>
                  </cv-radio-group>
                  <NsTextInput
                    v-if="recycle_retention_radio === 'limited'"
                    v-model.trim="recycle_retention"
                    :label="$t('shares.recycle_retention')"
                    :invalid-message="error.recycle_retention"
                    :disabled="loading.addShare"
                    ref="recycle_retention"
                    :placeholder="$t('shares.recycle_retention_placeholder')"
                    :helper-text="$t('shares.recycle_retention_helper_text')"
                    type="number"
                    min="1"
                    step="1"
                    max="9999"
                  />
                  <label class="bx--label">
                    {{ $t("shares.recycle_versions_title") }}
                  </label>
                  <cv-radio-group vertical>
                    <cv-radio-button
                      v-model="recycle_versions"
                      value="last"
                      :label="$t('shares.keep_last_versions')"
                      ref="recycle_versions_last"
                      :disabled="loading.addShare"
                      checked
                    ></cv-radio-button>
                    <cv-radio-button
                      v-model="recycle_versions"
                      value="multiple"
                      :label="$t('shares.keep_multiple_versions')"
                      :disabled="loading.addShare"
                      ref="recycle_retention_multiple"
                    ></cv-radio-button>
                  </cv-radio-group>
                </template>
              </div>
            </template>
          </cv-accordion-item>
        </cv-accordion>
      </cv-form>
    </template>
    <template slot="secondary-button">{{ core.$t("common.cancel") }}</template>
    <template slot="primary-button">{{
      $t("shares.create_shared_folder")
    }}</template>
  </NsModal>
</template>

<script>
import { UtilService, TaskService, IconService } from "@nethserver/ns8-ui-lib";
import to from "await-to-js";
import { mapState } from "vuex";
import PermissionsSelector from "./PermissionsSelector.vue";

export default {
  name: "CreateSharedFolderModal",
  components: { PermissionsSelector },
  mixins: [UtilService, TaskService, IconService],
  props: {
    isShown: Boolean,
  },
  data() {
    return {
      name: "",
      description: "",
      group: "",
      groups: [],
      DEFAULT_GROUP: "Domain Admins",
      permissions: "ergrw",
      enable_recycle: false,
      recycle_retention: "30",
      recycle_retention_radio: "limited",
      browseable: false,
      enable_audit: false,
      log_failed_events: false,
      recycle_versions: "last",
      loading: {
        addShare: false,
        listDomainGroups: false,
      },
      error: {
        addShare: "",
        listDomainGroups: "",
        name: "",
        description: "",
        group: "",
        permissions: "",
        enable_recycle: "",
        recycle_retention: "",
        browseable: "",
        enable_audit: "",
        log_failed_events: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName", "configuration"]),
    groupsForComboBox() {
      return this.groups.map((group) => {
        return {
          value: group.group,
          label: group.group,
          name: group.group,
        };
      });
    },
  },
  watch: {
    isShown: function () {
      if (this.isShown) {
        this.clearErrors();

        // reset all fields
        this.name = "";
        this.description = "";
        this.group = "";
        this.permissions = "ergrw";
        this.enable_recycle = false;
        this.recycle_retention = "30";
        this.recycle_retention_radio = "limited";
        this.browseable = false;
        this.enable_audit = false;
        this.log_failed_events = false;
        this.recycle_versions = "last";
        if (this.configuration) {
          this.listDomainGroups();
        }
      }
    },
    configuration: function () {
      if (this.configuration) {
        this.listDomainGroups();
      }
    },
    "error.addShare": function () {
      if (this.error.addShare) {
        // scroll to notification error

        this.$nextTick(() => {
          const el = this.$refs.addShareError;
          this.scrollToElement(el);
        });
      }
    },
  },
  methods: {
    validateAddShare() {
      this.clearErrors();
      let isValidationOk = true;

      // name

      if (!this.name) {
        this.error.name = this.$t("common.required");

        if (isValidationOk) {
          this.focusElement("name");
          isValidationOk = false;
        }
      }

      // group

      if (!this.group) {
        this.error.group = this.$t("common.required");

        if (isValidationOk) {
          this.focusElement("group");
          isValidationOk = false;
        }
      }

      // permissions

      if (!this.permissions) {
        this.error.permissions = this.$t("common.required");

        if (isValidationOk) {
          isValidationOk = false;
        }
      }

      // enable_recycle
      if (this.enable_recycle && this.recycle_retention_radio === "limited") {
        if (
          this.recycle_retention === "" ||
          isNaN(Number(this.recycle_retention))
        ) {
          this.error.recycle_retention = this.$t("error.must_be_a_number");
          this.focusElement("recycle_retention");
          isValidationOk = false;
        } else if (!Number.isInteger(Number(this.recycle_retention))) {
          this.error.recycle_retention = this.$t("error.must_be_an_integer");
          this.focusElement("recycle_retention");
          isValidationOk = false;
        } else if (Number(this.recycle_retention) < 1) {
          this.error.recycle_retention = this.$t(
            "error.must_be_greater_than_zero"
          );
          this.focusElement("recycle_retention");
          isValidationOk = false;
        } else if (Number(this.recycle_retention) > 9999) {
          this.error.recycle_retention = this.$t(
            "error.must_be_less_than_10000"
          );
          this.focusElement("recycle_retention");
          isValidationOk = false;
        }
      }
      return isValidationOk;
    },
    async addShare() {
      if (!this.validateAddShare()) {
        return;
      }
      this.loading.addShare = true;
      this.error.addShare = "";
      const taskAction = "add-share";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.addShareAborted
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-ok-${eventId}`,
        this.addShareValidationOk
      );
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.addShareValidationFailed
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.addShareCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            name: this.name,
            description: this.description,
            group: this.group,
            permissions: this.permissions,
            enable_recycle: this.enable_recycle,
            recycle_retention:
              this.recycle_retention_radio == "unlimited"
                ? 0
                : Number(this.recycle_retention),
            browseable: this.browseable,
            enable_audit: this.enable_audit,
            log_failed_events: this.log_failed_events,
            recycle_versions: this.recycle_versions === "multiple",
          },
          extra: {
            title: this.$t("shares.create_shared_folder_name", {
              name: this.name,
            }),
            description: this.$t("common.processing"),
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.addShare = this.getErrorMessage(err);
        this.loading.addShare = false;
        return;
      }
    },
    addShareAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.loading.addShare = false;

      // hide modal so that user can see error notification
      this.$emit("hide");
    },
    addShareValidationOk() {
      this.loading.addShare = false;

      // hide modal after validation
      this.$emit("hide");
    },
    addShareValidationFailed(validationErrors) {
      this.loading.addShare = false;
      let focusAlreadySet = false;

      for (const validationError of validationErrors) {
        const param = validationError.parameter;

        // set i18n error message
        this.error[param] = this.$t("shares." + validationError.error);

        if (!focusAlreadySet) {
          this.focusElement(param);
          focusAlreadySet = true;
        }
      }
    },
    addShareCompleted() {
      this.loading.addShare = false;

      // hide modal
      this.$emit("hide");

      // reload admins
      this.$emit("shareCreated");
    },
    onModalHidden() {
      this.clearErrors();
      this.$emit("hide");
    },
    async listDomainGroups() {
      this.loading.listDomainGroups = true;
      this.error.listDomainGroups = "";
      const taskAction = "list-domain-groups";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.listDomainGroupsAborted
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.listDomainGroupsCompleted
      );

      const res = await to(
        this.createClusterTaskForApp({
          action: taskAction,
          data: {
            domain: this.configuration.domain,
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
        this.error.listDomainGroups = this.getErrorMessage(err);
        return;
      }
    },
    listDomainGroupsAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.listDomainGroups = this.$t("error.generic_error");
      this.loading.listDomainGroups = false;
    },
    listDomainGroupsCompleted(taskContext, taskResult) {
      this.groups = taskResult.output.groups;
      this.loading.listDomainGroups = false;

      setTimeout(() => {
        this.group = this.DEFAULT_GROUP;
      }, 100);
    },
    onPermissionsSelected(permissions) {
      this.permissions = permissions;
    },
  },
};
</script>

<style scoped lang="scss">
@import "../../styles/carbon-utils";
</style>
