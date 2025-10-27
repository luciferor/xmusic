import { createStore } from "vuex";

export default createStore({
  state: {
    loading: false,
    tabActive: 0,
  },
  getters: {},
  mutations: {
    setLoadingState(state, e) {
      state.loading = e;
    },
    setTabActive(state, e) {
      state.tabActive = e;
    }
  },
  actions: {},
  modules: {},
});
