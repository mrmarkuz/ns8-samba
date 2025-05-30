<!--
  Copyright (C) 2023 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <div>
    <div class="perm-selector">
      <!-- everybody read, main group read and write -->
      <NsTile
        light
        kind="selectable"
        v-model="ergrwSelected"
        @click="permissionsSelected('ergrw')"
        value="permissionsValue"
        :disabled="disabled"
        class="perm"
      >
        <div>
          <span>{{ $t("shares.ergrw_description") }}</span>
        </div>
      </NsTile>
      <!-- only main group read and write -->
      <NsTile
        light
        kind="selectable"
        v-model="grwSelected"
        @click="permissionsSelected('grw')"
        value="permissionsValue"
        :disabled="disabled"
        class="perm"
      >
        <div>
          <span>{{ $t("shares.grw_description") }}</span>
        </div>
      </NsTile>
      <!-- everybody read and write -->
      <NsTile
        light
        kind="selectable"
        v-model="erwSelected"
        @click="permissionsSelected('erw')"
        value="permissionsValue"
        :disabled="disabled"
        class="perm"
      >
        <div>
          <span>{{ $t("shares.erw_description") }}</span>
        </div>
      </NsTile>
    </div>
    <!-- validation error -->
    <div v-if="validationErrorMessage" class="perm-error">
      {{ validationErrorMessage }}
    </div>
  </div>
</template>

<script>
import { UtilService, TaskService, IconService } from "@nethserver/ns8-ui-lib";

export default {
  name: "PermissionsSelector",
  mixins: [UtilService, TaskService, IconService],
  props: {
    permissions: { type: String, default: "" },
    disabled: { type: Boolean, default: false },
    validationErrorMessage: { type: String, default: "" },
  },
  data() {
    return {
      internalPermissions: "",
      // everybody read, main group read and write
      ergrwSelected: true,
      // only main group read and write
      grwSelected: false,
      // everybody read and write
      erwSelected: false,
    };
  },
  created() {
    this.updateInternalPermissions();
  },
  watch: {
    permissions: function () {
      this.updateInternalPermissions();
    },
  },
  methods: {
    updateInternalPermissions() {
      this.internalPermissions = this.permissions;

      switch (this.internalPermissions) {
        case "ergrw":
          this.ergrwSelected = true;
          this.grwSelected = false;
          this.erwSelected = false;
          break;
        case "grw":
          this.ergrwSelected = false;
          this.grwSelected = true;
          this.erwSelected = false;
          break;
        case "erw":
          this.ergrwSelected = false;
          this.grwSelected = false;
          this.erwSelected = true;
          break;
        case "":
          this.ergrwSelected = false;
          this.grwSelected = false;
          this.erwSelected = false;
      }
    },
    permissionsSelected(permissions) {
      this.internalPermissions = permissions;

      switch (permissions) {
        case "ergrw":
          this.grwSelected = false;
          this.erwSelected = false;

          setTimeout(() => {
            this.$emit("selected", this.ergrwSelected ? "ergrw" : "");
          }, 100);
          break;
        case "grw":
          this.ergrwSelected = false;
          this.erwSelected = false;

          setTimeout(() => {
            this.$emit("selected", this.grwSelected ? "grw" : "");
          }, 100);
          break;
        case "erw":
          this.ergrwSelected = false;
          this.grwSelected = false;

          setTimeout(() => {
            this.$emit("selected", this.erwSelected ? "erw" : "");
          }, 100);
          break;
      }
    },
  },
};
</script>

<style scoped lang="scss">
@import "../../styles/carbon-utils";

.perm-selector {
  display: flex;
  gap: $spacing-05;
  padding: 0;
}

.perm {
  width: 33%;
  margin-bottom: 0 !important;
}

.perm-error {
  color: $danger-01 !important;
  font-size: 0.75rem;
  line-height: 1.33333;
  letter-spacing: 0.32px;
  margin: 0.25rem 0 0;
  overflow: visible;
  max-height: 12.5rem;
  font-weight: 400;
  margin-bottom: $spacing-07;
}
</style>
