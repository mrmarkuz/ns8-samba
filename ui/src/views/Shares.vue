<!--
  Copyright (C) 2023 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <div>
    <cv-grid fullWidth>
      <cv-row>
        <cv-column class="page-title">
          <h2>{{ $t("shares.title") }}</h2>
        </cv-column>
      </cv-row>
      <cv-row v-if="error.listShares">
        <cv-column>
          <NsInlineNotification
            kind="error"
            :title="$t('action.list-shares')"
            :description="error.listShares"
            :showCloseButton="false"
          />
        </cv-column>
      </cv-row>
      <cv-row v-if="!loading.listShares && shares.length" class="toolbar">
        <cv-column>
          <NsButton
            kind="secondary"
            :icon="Add20"
            @click="showCreateSharedFolderModal"
            >{{ $t("shares.create_shared_folder") }}
          </NsButton>
          <NsButton
            kind="tertiary"
            @click="showAccessSharesInfoModal"
            class="mg-left-md"
          >
            {{ $t("shares.how_to_access_shared_folders") }}
          </NsButton>
        </cv-column>
      </cv-row>
      <cv-row>
        <!-- shares table -->
        <cv-column>
          <NsDataTable
            :allRows="shares"
            :columns="i18nTableColumns"
            :rawColumns="tableColumns"
            :sortable="true"
            :pageSizes="[10, 25, 50, 100]"
            :overflow-menu="true"
            isSearchable
            :searchPlaceholder="$t('shares.search_folder')"
            :searchClearLabel="core.$t('common.clear_search')"
            :noSearchResultsLabel="core.$t('common.no_search_results')"
            :noSearchResultsDescription="
              core.$t('common.no_search_results_description')
            "
            :isLoading="loading.listShares"
            :skeletonRows="5"
            :isErrorShown="!!error.listShares"
            :errorTitle="$t('action.list-shares')"
            :errorDescription="error.listShares"
            :itemsPerPageLabel="core.$t('pagination.items_per_page')"
            :rangeOfTotalItemsLabel="core.$t('pagination.range_of_total_items')"
            :ofTotalPagesLabel="core.$t('pagination.of_total_pages')"
            :backwardText="core.$t('pagination.previous_page')"
            :forwardText="core.$t('pagination.next_page')"
            :pageNumberLabel="core.$t('pagination.page_number')"
            @updatePage="tablePage = $event"
          >
            <template slot="empty-state">
              <NsEmptyState :title="$t('shares.no_shares')">
                <template #pictogram>
                  <FolderPictogram />
                </template>
                <template #description>
                  <NsButton
                    kind="primary"
                    :icon="Add20"
                    @click="showCreateSharedFolderModal"
                    class="empty-state-button"
                    >{{ $t("shares.create_shared_folder") }}</NsButton
                  >
                </template>
              </NsEmptyState>
            </template>
            <template slot="data">
              <cv-data-table-row
                v-for="(row, rowIndex) in tablePage"
                :key="`${rowIndex}`"
                :value="`${rowIndex}`"
              >
                <cv-data-table-cell>
                  <span>{{ row.name }}</span>
                </cv-data-table-cell>
                <cv-data-table-cell>
                  {{ row.description || "-" }}
                </cv-data-table-cell>
                <cv-data-table-cell
                  class="table-overflow-menu-cell actions-column"
                >
                  <NsButton
                    kind="ghost"
                    @click="showAclsModal(row)"
                    class="mg-right-25"
                    >{{ $t("shares.show_acls") }}
                  </NsButton>
                  <cv-overflow-menu flip-menu class="table-overflow-menu">
                    <cv-overflow-menu-item
                      @click="showEditDescriptionModal(row)"
                    >
                      <NsMenuItem
                        :icon="Edit20"
                        :label="$t('shares.edit_description')"
                      />
                    </cv-overflow-menu-item>
                    <cv-overflow-menu-item
                      @click="showSetPermissionsModal(row)"
                    >
                      <NsMenuItem
                        :icon="Locked20"
                        :label="$t('shares.set_permissions')"
                      />
                    </cv-overflow-menu-item>
                    <cv-overflow-menu-item @click="showRestoreFileModal(row)">
                      <NsMenuItem
                        :icon="RecentlyViewed20"
                        :label="$t('shares.restore_file_or_folder')"
                      />
                    </cv-overflow-menu-item>
                    <cv-overflow-menu-item
                      danger
                      @click="showDeleteShareModal(row)"
                    >
                      <NsMenuItem
                        :icon="TrashCan20"
                        :label="core.$t('common.delete')"
                      />
                    </cv-overflow-menu-item>
                  </cv-overflow-menu>
                </cv-data-table-cell>
              </cv-data-table-row>
            </template>
          </NsDataTable>
        </cv-column>
      </cv-row>
    </cv-grid>
    <!-- create shared folder modal -->
    <CreateSharedFolderModal
      :isShown="isShownCreateSharedFolderModal"
      @hide="hideCreateSharedFolderModal"
      @shareCreated="onShareCreated"
    />
    <!-- edit description modal -->
    <EditDescriptionModal
      :isShown="isShownEditDescriptionModal"
      :share="currentShare"
      @hide="hideEditDescriptionModal"
      @descriptionUpdated="onDescriptionUpdated"
    />
    <!-- show acls modal -->
    <ShowAclsModal
      :isShown="isShownAclsModal"
      :share="currentShare"
      @hide="hideAclsModal"
    />
    <!-- set permissions modal -->
    <SetPermissionsModal
      :isShown="isShownSetPermissionsModal"
      :share="currentShare"
      @hide="hideSetPermissionsModal"
      @permissionsUpdated="onPermissionsUpdated"
    />
    <!-- restore file modal -->
    <RestoreFileModal
      :isShown="isShownRestoreFileModal"
      :shareName="currentShare ? currentShare.name : ''"
      @hide="hideRestoreFileModal"
    />
    <!-- delete share modal -->
    <NsDangerDeleteModal
      :isShown="isShownDeleteShareModal"
      :name="currentShare ? currentShare.name : ''"
      :title="
        $t('shares.delete_shared_folder_name', {
          name: currentShare ? currentShare.name : '',
        })
      "
      :warning="core.$t('common.please_read_carefully')"
      :description="
        $t('shares.delete_shared_folder_description', {
          name: currentShare ? currentShare.name : '',
        })
      "
      :typeToConfirm="
        core.$t('common.type_to_confirm', {
          name: currentShare ? currentShare.name : '',
        })
      "
      :isErrorShown="!!error.removeShare"
      :errorTitle="$t('action.remove-share')"
      :errorDescription="error.removeShare"
      :loading="loading.removeShare"
      @hide="hideDeleteShareModal"
      @confirmDelete="removeShare"
    />
    <!-- access shares info modal -->
    <AccessSharesInfoModal
      :isShown="isShownAccessSharesInfoModal"
      @hide="hideAccessSharesInfoModal"
    />
  </div>
</template>

<script>
import to from "await-to-js";
import { mapState } from "vuex";
import {
  QueryParamService,
  UtilService,
  TaskService,
  IconService,
  PageTitleService,
} from "@nethserver/ns8-ui-lib";
import CreateSharedFolderModal from "@/components/shared-folders/CreateSharedFolderModal.vue";
import EditDescriptionModal from "@/components/shared-folders/EditDescriptionModal.vue";
import ShowAclsModal from "@/components/shared-folders/ShowAclsModal.vue";
import SetPermissionsModal from "@/components/shared-folders/SetPermissionsModal.vue";
import AccessSharesInfoModal from "@/components/shared-folders/AccessSharesInfoModal.vue";
import RecentlyViewed20 from "@carbon/icons-vue/es/recently-viewed/20";
import RestoreFileModal from "@/components/shared-folders/RestoreFileModal.vue";

export default {
  name: "Settings",
  components: {
    CreateSharedFolderModal,
    EditDescriptionModal,
    ShowAclsModal,
    SetPermissionsModal,
    RestoreFileModal,
    AccessSharesInfoModal,
  },
  mixins: [
    TaskService,
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
  ],
  pageTitle() {
    return this.$t("shares.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "shares",
      },
      urlCheckInterval: null,
      shares: [],
      isShownCreateSharedFolderModal: false,
      isShownEditDescriptionModal: false,
      isShownAclsModal: false,
      isShownSetPermissionsModal: false,
      isShownRestoreFileModal: false,
      isShownDeleteShareModal: false,
      isShownAccessSharesInfoModal: false,
      currentShare: null,
      RecentlyViewed20,
      tableColumns: ["name", "description"],
      tablePage: [],
      loading: {
        listShares: false,
        removeShare: false,
      },
      error: {
        listShares: "",
        removeShare: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
    i18nTableColumns() {
      return this.tableColumns.map((column) => {
        return this.$t("shares.column_" + column);
      });
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
    this.listShares();
  },
  methods: {
    async listShares() {
      this.loading.listShares = true;
      this.error.listShares = "";
      const taskAction = "list-shares";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.listSharesAborted
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.listSharesCompleted
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
        this.error.listShares = this.getErrorMessage(err);
        this.loading.listShares = false;
        return;
      }
    },
    listSharesAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.listShares = this.$t("error.generic_error");
      this.loading.listShares = false;
    },
    listSharesCompleted(taskContext, taskResult) {
      this.loading.listShares = false;
      this.shares = taskResult.output.shares;
    },
    showCreateSharedFolderModal() {
      this.isShownCreateSharedFolderModal = true;
    },
    hideCreateSharedFolderModal() {
      this.isShownCreateSharedFolderModal = false;
    },
    showAccessSharesInfoModal() {
      this.isShownAccessSharesInfoModal = true;
    },
    hideAccessSharesInfoModal() {
      this.isShownAccessSharesInfoModal = false;
    },
    onShareCreated() {
      this.listShares();
    },
    showEditDescriptionModal(share) {
      this.currentShare = share;
      this.isShownEditDescriptionModal = true;
    },
    hideEditDescriptionModal() {
      this.isShownEditDescriptionModal = false;
    },
    onDescriptionUpdated() {
      this.listShares();
    },
    showAclsModal(share) {
      this.currentShare = share;
      this.isShownAclsModal = true;
    },
    hideAclsModal() {
      this.isShownAclsModal = false;
    },
    showSetPermissionsModal(share) {
      this.currentShare = share;
      this.isShownSetPermissionsModal = true;
    },
    hideSetPermissionsModal() {
      this.isShownSetPermissionsModal = false;
    },
    showRestoreFileModal(share) {
      this.currentShare = share;
      this.isShownRestoreFileModal = true;
    },
    hideRestoreFileModal() {
      this.isShownRestoreFileModal = false;
    },
    onPermissionsUpdated() {
      this.listShares();
    },
    showDeleteShareModal(share) {
      this.currentShare = share;
      this.isShownDeleteShareModal = true;
    },
    hideDeleteShareModal() {
      this.isShownDeleteShareModal = false;
    },
    async removeShare() {
      this.loading.removeShare = true;
      this.error.removeShare = "";
      const taskAction = "remove-share";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.removeShareAborted
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-ok-${eventId}`,
        this.removeShareValidationOk
      );
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.removeShareValidationFailed
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.removeShareCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            name: this.currentShare.name,
          },
          extra: {
            title: this.$t("shares.delete_shared_folder_name", {
              name: this.currentShare.name,
            }),
            description: this.$t("common.processing"),
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.removeShare = this.getErrorMessage(err);
        this.loading.removeShare = false;
        return;
      }
    },
    removeShareAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.loading.removeShare = false;

      // hide modal so that user can see error notification
      this.hideDeleteShareModal();
    },
    removeShareValidationOk() {
      this.loading.removeShare = false;

      // hide modal after validation
      this.hideDeleteShareModal();
    },
    removeShareValidationFailed(validationErrors) {
      this.loading.removeShare = false;

      for (const validationError of validationErrors) {
        // set i18n error message
        this.error.removeShare = this.$t("shares." + validationError.error);
      }
    },
    removeShareCompleted() {
      this.loading.removeShare = false;

      // hide modal
      this.hideDeleteShareModal();

      // reload shares
      this.listShares();
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";

.share-card-content .row {
  margin-bottom: $spacing-05;
  text-align: center;
}

.share-card-content .row:last-child {
  margin-bottom: 0;
}

.actions {
  margin-top: $spacing-06;
}

.description {
  color: $text-02;
}

.actions-column {
  display: flex;
  justify-content: flex-end;
}

.mg-right-25 {
  margin-right: 2.5rem;
}
</style>
