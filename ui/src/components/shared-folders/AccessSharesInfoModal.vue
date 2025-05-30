<!--
  Copyright (C) 2025 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <NsModal
    size="default"
    :visible="isShown"
    @modal-hidden="onModalHidden"
    @primary-click="onModalHidden"
  >
    <template slot="title">
      {{ $t("shares.how_to_access_shared_folders") }}
    </template>
    <template slot="content">
      <p class="mg-bottom-lg">
        {{ $t("shares.how_to_access_shared_folders_description") }}
      </p>
      <label class="bx--label">
        {{
          $tc(
            "shares.network_path_examples",
            configuration && configuration.nbalias ? 2 : 1
          )
        }}
      </label>
      <NsCodeSnippet
        :copyTooltip="core.$t('common.copy_to_clipboard')"
        :copy-feedback="core.$t('common.copied_to_clipboard')"
        :feedback-aria-label="core.$t('common.copied_to_clipboard')"
        :wrap-text="true"
        :moreText="core.$t('common.show_more')"
        :lessText="core.$t('common.show_less')"
        light
        hideExpandButton
        class="mg-bottom-lg"
      >
        \\{{ configuration && configuration.hostname }}\exampleshare
        <br />
        <br />
        <div v-if="configuration && configuration.nbalias">
          \\{{ configuration.nbalias }}\exampleshare
        </div>
      </NsCodeSnippet>
      <label class="bx--label">
        {{ $t("shares.username_format_examples") }}
      </label>
      <NsCodeSnippet
        :copyTooltip="core.$t('common.copy_to_clipboard')"
        :copy-feedback="core.$t('common.copied_to_clipboard')"
        :feedback-aria-label="core.$t('common.copied_to_clipboard')"
        :wrap-text="true"
        :moreText="core.$t('common.show_more')"
        :lessText="core.$t('common.show_less')"
        light
        hideExpandButton
      >
        {{ configuration && configuration.nbdomain }}\john.doe
        <br />
        <br />
        john.doe@{{ configuration && configuration.realm }}
        <br />
        <br />
        john.doe
      </NsCodeSnippet>
    </template>
    <template slot="primary-button">{{ core.$t("common.close") }}</template>
  </NsModal>
</template>

<script>
import { UtilService, TaskService, IconService } from "@nethserver/ns8-ui-lib";
import { mapState } from "vuex";

export default {
  name: "AccessSharesInfoModal",
  mixins: [UtilService, TaskService, IconService],
  props: {
    isShown: Boolean,
    share: Object,
  },
  computed: {
    ...mapState(["core", "configuration"]),
  },
  methods: {
    onModalHidden() {
      this.$emit("hide");
    },
    getAclColor(rights) {
      switch (rights) {
        case "ro":
          return "green";
        case "rw":
          return "red";
        case "full":
          return "high-contrast";
        default:
          return "blue";
      }
    },
  },
};
</script>

<style scoped lang="scss">
@import "../../styles/carbon-utils";
</style>
