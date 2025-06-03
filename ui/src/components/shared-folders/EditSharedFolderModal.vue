<!--
  Copyright (C) 2023 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <NsModal
    size="default"
    :visible="isShown"
    :primary-button-disabled="loading.alterShare"
    @modal-hidden="onModalHidden"
    @primary-click="alterShare"
  >
    <template slot="title">{{ $t("shares.edit_shared_folder") }}</template>
    <template slot="content">
      <cv-form @submit.prevent="alterShare">
        <cv-text-input
          :label="
            $t('shares.description') + ' (' + core.$t('common.optional') + ')'
          "
          v-model.trim="newDescription"
          :placeholder="$t('shares.no_description')"
          ref="newDescription"
        >
        </cv-text-input>
        <div v-if="error.alterShare">
          <NsInlineNotification
            kind="error"
            :title="$t('action.alter-share')"
            :description="error.alterShare"
            :showCloseButton="false"
          />
        </div>
        <!-- advanced options -->
        <cv-accordion ref="accordion" class="mg-top-lg">
          <cv-accordion-item :open="toggleAccordion[0]">
            <template slot="title">{{ core.$t("common.advanced") }}</template>
            <template slot="content">
              <NsToggle
                value="newEnable_audit"
                :label="$t('shares.enable_audit')"
                v-model="newEnable_audit"
                :form-item="true"
                :disabled="loading.addShare"
                :error-message="error.newEnable_audit"
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
                v-if="newEnable_audit"
                value="newLog_failed_events"
                :label="$t('shares.log_failed_events')"
                v-model="newLog_failed_events"
                :form-item="true"
                :disabled="loading.addShare"
                :error-message="error.newLog_failed_events"
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
                value="newBrowseable"
                :label="$t('shares.browseable')"
                v-model="newBrowseable"
                :form-item="true"
                :disabled="loading.addShare"
                :error-message="error.newBrowseable"
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
                value="newEnable_recycle"
                :label="$t('shares.enable_recycle')"
                v-model="newEnable_recycle"
                :form-item="true"
                :disabled="loading.addShare"
                :error-message="error.newEnable_recycle"
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
                <template v-if="newEnable_recycle">
                  <label class="bx--label">
                    {{ $t("shares.retention") }}
                  </label>
                  <cv-radio-group vertical>
                    <cv-radio-button
                      v-model="newRecycle_retention_radio"
                      value="limited"
                      :label="$t('shares.limited')"
                      ref="recycle_retention_radio_limited"
                      :disabled="loading.addShare"
                      checked
                    ></cv-radio-button>
                    <cv-radio-button
                      v-model="newRecycle_retention_radio"
                      value="unlimited"
                      :label="$t('shares.unlimited')"
                      :disabled="loading.addShare"
                      ref="recycle_retention_radio_unlimited"
                    ></cv-radio-button>
                  </cv-radio-group>
                  <NsTextInput
                    v-if="newRecycle_retention_radio === 'limited'"
                    v-model.trim="newRecycle_retention"
                    :label="$t('shares.recycle_retention')"
                    :invalid-message="error.newRecycle_retention"
                    :disabled="loading.addShare"
                    ref="newRecycle_retention"
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
                      v-model="newRecycle_versions"
                      value="last"
                      :label="$t('shares.keep_last_versions')"
                      ref="recycle_versions_last"
                      :disabled="loading.addShare"
                      checked
                    ></cv-radio-button>
                    <cv-radio-button
                      v-model="newRecycle_versions"
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
    <template slot="primary-button">{{ $t("common.save") }}</template>
  </NsModal>
</template>

<script>
import { UtilService, TaskService, IconService } from "@nethserver/ns8-ui-lib";
import to from "await-to-js";
import { mapState } from "vuex";

export default {
  name: "EditSharedFolderModal",
  mixins: [UtilService, TaskService, IconService],
  props: {
    isShown: Boolean,
    share: Object,
  },
  data() {
    return {
      newDescription: "",
      newEnable_recycle: false,
      newRecycle_retention: "30",
      newRecycle_retention_radio: "limited",
      newBrowseable: false,
      newEnable_audit: false,
      newLog_failed_events: false,
      newRecycle_versions: "last",
      loading: {
        alterShare: false,
      },
      error: {
        alterShare: "",
        newDescription: "",
        newEnable_recycle: "",
        newRecycle_retention: "",
        newBrowseable: "",
        newEnable_audit: "",
        newLog_failed_events: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
  },
  watch: {
    isShown: function () {
      if (this.isShown) {
        this.clearErrors();
        this.newDescription = this.share.description;
        this.newEnable_recycle = this.share.enable_recycle;
        this.newRecycle_retention = String(this.share.recycle_retention);
        this.newRecycle_retention_radio =
          this.share.recycle_retention == 0 ? "unlimited" : "limited";
        this.newBrowseable = this.share.browseable;
        this.newEnable_audit = this.share.enable_audit;
        this.newLog_failed_events = this.share.log_failed_events;
        this.newRecycle_versions = this.share.recycle_versions
          ? "multiple"
          : "last";
        setTimeout(() => {
          this.focusElement("newDescription");
        }, 300);
      }
    },
  },
  methods: {
    validateAlterShare() {
      this.clearErrors();
      let isValidationOk = true;

      if (
        this.newEnable_recycle &&
        this.newRecycle_retention_radio === "limited"
      ) {
        if (
          this.newRecycle_retention === "" ||
          isNaN(Number(this.newRecycle_retention))
        ) {
          this.error.newRecycle_retention = this.$t("error.must_be_a_number");
          this.focusElement("newRecycle_retention");
          isValidationOk = false;
        } else if (!Number.isInteger(Number(this.newRecycle_retention))) {
          this.error.newRecycle_retention = this.$t("error.must_be_an_integer");
          this.focusElement("newRecycle_retention");
          isValidationOk = false;
        } else if (Number(this.newRecycle_retention) < 1) {
          this.error.newRecycle_retention = this.$t(
            "error.must_be_greater_than_zero"
          );
          this.focusElement("newRecycle_retention");
          isValidationOk = false;
        } else if (Number(this.newRecycle_retention) > 9999) {
          this.error.newRecycle_retention = this.$t(
            "error.must_be_less_than_10000"
          );
          this.focusElement("newRecycle_retention");
          isValidationOk = false;
        }
      }
      return isValidationOk;
    },
    async alterShare() {
      if (!this.validateAlterShare()) {
        return;
      }
      this.loading.alterShare = true;
      this.error.alterShare = "";
      const taskAction = "alter-share";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.alterShareAborted
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.alterShareCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            name: this.share.name,
            description: this.newDescription,
            enable_recycle: this.newEnable_recycle,
            recycle_retention:
              this.newRecycle_retention_radio == "unlimited"
                ? 0
                : Number(this.newRecycle_retention),
            browseable: this.newBrowseable,
            enable_audit: this.newEnable_audit,
            log_failed_events: this.newLog_failed_events,
            recycle_versions: this.newRecycle_versions === "multiple",
          },
          extra: {
            title: this.$t("shares.edit_shared_folder"),
            description: this.$t("common.processing"),
            eventId,
          },
        })
      );

      const err = res[0];
      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.alterShare = this.getErrorMessage(err);
        this.loading.alterShare = false;
        return;
      }
    },
    alterShareAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.loading.alterShare = false;
      // hide modal so that user can see error notification
      this.$emit("hide");
    },
    alterShareCompleted() {
      this.loading.alterShare = false;
      this.$emit("hide");
      this.$emit("descriptionUpdated");
    },
    onModalHidden() {
      this.clearErrors();
      this.$emit("hide");
    },
  },
};
</script>

<style scoped lang="scss">
@import "../../styles/carbon-utils";
</style>
