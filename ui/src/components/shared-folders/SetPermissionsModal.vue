<!--
  Copyright (C) 2023 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <NsModal
    size="default"
    :visible="isShown"
    :primary-button-disabled="loading.resetShareAcls"
    :isLoading="loading.resetShareAcls"
    @modal-hidden="onModalHidden"
    @primary-click="resetShareAcls"
    class="no-pad-modal"
  >
    <template slot="title">{{
      $t("shares.set_shared_folder_permissions")
    }}</template>
    <template slot="content">
      <cv-form @submit.prevent="resetShareAcls">
        <NsInlineNotification
          kind="warning"
          :title="core.$t('common.warning')"
          :description="
            $t('shares.set_shared_folder_permissions_explanation', {
              name: share ? share.name : '',
            })
          "
          :showCloseButton="false"
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
          :disabled="loading.resetShareAcls || loading.listDomainGroups"
          tooltipAlignment="start"
          tooltipDirection="bottom"
          light
          ref="group"
        >
          <template slot="tooltip">
            <div>{{ $t("shares.main_group_tooltip") }}</div>
          </template>
        </NsComboBox>
        <!-- permissions -->
        <label class="bx--label">
          {{ $t("shares.permissions") }}
        </label>
        <PermissionsSelector
          :permissions="permissions"
          :disabled="loading.resetShareAcls"
          :validationErrorMessage="error.permissions"
          @selected="onPermissionsSelected"
        />
        <!-- need to wrap error notification inside a div: custom elements like NsInlineNotification don't have scrollIntoView() function -->
        <div ref="resetShareAclsError">
          <NsInlineNotification
            v-if="error.resetShareAcls"
            kind="error"
            :title="$t('action.reset-share-acls')"
            :description="error.resetShareAcls"
            :showCloseButton="false"
          />
        </div>
      </cv-form>
    </template>
    <template slot="secondary-button">{{ core.$t("common.cancel") }}</template>
    <template slot="primary-button">{{
      $t("shares.set_permissions")
    }}</template>
  </NsModal>
</template>

<script>
import { UtilService, TaskService, IconService } from "@nethserver/ns8-ui-lib";
import to from "await-to-js";
import { mapState } from "vuex";
import PermissionsSelector from "./PermissionsSelector.vue";

export default {
  name: "SetPermissionsModal",
  components: { PermissionsSelector },
  mixins: [UtilService, TaskService, IconService],
  props: {
    isShown: Boolean,
    share: Object,
  },
  data() {
    return {
      group: "",
      groups: [],
      DEFAULT_GROUP: "Domain Admins",
      permissions: "",
      loading: {
        resetShareAcls: false,
        listDomainGroups: false,
      },
      error: {
        resetShareAcls: "",
        listDomainGroups: "",
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

        // reset fields
        this.group = this.DEFAULT_GROUP;
        this.permissions = "";

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
    "error.resetShareAcls": function () {
      if (this.error.resetShareAcls) {
        // scroll to notification error

        this.$nextTick(() => {
          const el = this.$refs.resetShareAclsError;
          this.scrollToElement(el);
        });
      }
    },
  },
  methods: {
    validateResetShareAcls() {
      this.clearErrors();
      let isValidationOk = true;

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
    async resetShareAcls() {
      if (!this.validateResetShareAcls()) {
        return;
      }
      this.loading.resetShareAcls = true;
      this.error.resetShareAcls = "";
      const taskAction = "reset-share-acls";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.resetShareAclsAborted
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-ok-${eventId}`,
        this.resetShareAclsValidationOk
      );
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.resetShareAclsValidationFailed
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.resetShareAclsCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            name: this.share.name,
            group: this.group,
            permissions: this.permissions,
          },
          extra: {
            title: this.$t("shares.set_permissions_for_share_name", {
              name: this.share.name,
            }),
            description: this.$t("common.processing"),
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.resetShareAcls = this.getErrorMessage(err);
        this.loading.resetShareAcls = false;
        return;
      }
    },
    resetShareAclsAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.loading.resetShareAcls = false;

      // hide modal so that user can see error notification
      this.$emit("hide");
    },
    resetShareAclsValidationOk() {
      this.loading.resetShareAcls = false;

      // hide modal after validation
      this.$emit("hide");
    },
    resetShareAclsValidationFailed(validationErrors) {
      this.loading.resetShareAcls = false;

      for (const validationError of validationErrors) {
        // set i18n error message
        this.error.resetShareAcls = this.$t("shares." + validationError.error);
      }
    },
    resetShareAclsCompleted() {
      this.loading.resetShareAcls = false;

      // hide modal
      this.$emit("hide");

      // reload admins
      this.$emit("permissionsUpdated");
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

      this.$nextTick(() => {
        this.group = this.DEFAULT_GROUP;
      });
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
