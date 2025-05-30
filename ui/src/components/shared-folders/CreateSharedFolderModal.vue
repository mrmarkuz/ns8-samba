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
