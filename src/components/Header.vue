<template>
  <!-- eslint-disable -->
  <div class="slim-header">
    <div class="container">
      <div class="slim-header-left">
        <h3 class="slim-logo"><router-link to="/"><img src="/static/img/logo-nbr.png" style="width: 50px" /> ArQmA NETWORK<span></span></router-link></h3>
      </div><!-- slim-header-left -->
      <div class="slim-header-right">
        <alerts :isNewAlerts="view.isNewAlerts" :alerts="alerts" />
        <div class="dropdown dropdown-c">
          <a href="#" class="logged-user" data-toggle="dropdown">
            <img src="/static/img/abstract-user-flat-3.svg" alt="">
            <span>{{ user.name }}</span>
            <i class="fa fa-angle-down"></i>
          </a>
          <div class="dropdown-menu dropdown-menu-right">
            <nav class="nav">
              <router-link to="/me" class="nav-link"><i class="icon ion-person"></i> {{$t('menu.profile')}}</router-link>
              <router-link to="/settings" class="nav-link"><i class="icon ion-ios-gear"></i> {{$t('menu.settings')}}</router-link>
              <a href="#" @click="logout" class="nav-link"><i class="icon ion-forward"></i> {{$t('menu.signOut')}}</a>
            </nav>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import ControllerFactory from '@/lib/controllers/ControllerFactory'
import Thread from '@/lib/Thread'
import Alerts from '@/components/pages/header/Alerts'

export default {
  props: ['user'],

  components: {
    Alerts
  },

  data () {
    return {
      alerts: [],
      view: {
        isNewAlerts: false
      }
    }
  },

  mounted () {
    this.loadAlerts()

    this.thread = new Thread('checkIfThereIsNewAlerts', 5 * 1000, () => {
      this.checkIfThereIsNewAlerts()
    })
    this.thread.start()

    this.clearNewAlerts = new Thread('clearNewAlerts', 5 * 60 * 1000, () => {
      this.view.isNewAlerts = false
    })
    this.clearNewAlerts.start()
  },

  destroyed () {
    this.thread.stop()
    this.clearNewAlerts.stop()
  },

  methods: {
    logout () {
      const userController = ControllerFactory.getController('user', this)
      userController.logout()
      this.$router.push('/logout')
    },

    loadAlerts () {
      const alertController = ControllerFactory.getController('alert', this)

      alertController.getAlerts()
        .then(alerts => {
          this.alerts = alerts
        })
    },

    checkIfThereIsNewAlerts () {
      const alertController = ControllerFactory.getController('alert', this)

      alertController.getUnreadAlerts()
        .then(alerts => {
          if (alerts.length > 0) {
            this.view.isNewAlerts = true
            return this.loadAlerts()
          }
        })
    }
  }
}
</script>
