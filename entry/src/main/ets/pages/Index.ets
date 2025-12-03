import { MainHomePage } from './routes/main/MainHomePage'

const EXCITEMENT_MESSAGES: Resource[] = [
  $r('app.string.excitement_deadline_chasing'),
  $r('app.string.excitement_progress_1_to_99'),
  $r('app.string.excitement_ddl_bite'),
  $r('app.string.excitement_submit'),
  $r('app.string.excitement_get_up'),
  $r('app.string.excitement_5min_5h'),
  $r('app.string.excitement_todo_on_fire'),
  $r('app.string.excitement_today_task'),
  $r('app.string.excitement_ddl_near'),
  $r('app.string.excitement_classic_flag'),
  $r('app.string.excitement_reward_sleep'),
  $r('app.string.excitement_detect_anxiety'),
  $r('app.string.excitement_stop_scrolling'),
  $r('app.string.excitement_last_minute'),
  $r('app.string.excitement_mountains'),
  $r('app.string.excitement_ddl_power'),
  $r('app.string.excitement_im_okay'),
  $r('app.string.excitement_today_achievement'),
  $r('app.string.excitement_do_hard_first'),
  $r('app.string.excitement_next'),
]

@Entry
@Component
struct Index {
  pageStack: NavPathStack = new NavPathStack()

  settingsMenuItem: NavigationMenuItem = {
    value: "Settings",
    icon: 'resources/base/media/gearshape.svg',
    action: ()=> {
      this.pageStack.pushPathByName('settingsWebDav', null);
    }
  }
  searchMenuItem: NavigationMenuItem = {
    value: "Search",
    icon: 'resources/base/media/search.svg',
    action: ()=> {
      // TODO
    }
  }

  @State navSubtitle: string | undefined = undefined

  aboutToAppear(): void {
    const ctx = this.getUIContext()
    const idx = Math.floor(Math.random() * EXCITEMENT_MESSAGES.length)
    const res = EXCITEMENT_MESSAGES[idx]
    try {
      this.navSubtitle = ctx.getHostContext()?.resourceManager.getStringSync(res)
    } catch (error) {
      console.error('Unable to get String Resource')
    }
  }

  build() {
    Navigation(this.pageStack) {
      MainHomePage()
    }
    .title("Deadliner")
    .subTitle(this.navSubtitle)
    .titleMode(NavigationTitleMode.Free)
    .menus([
      this.searchMenuItem,
      this.settingsMenuItem
    ])
    .ignoreLayoutSafeArea(
      [LayoutSafeAreaType.SYSTEM],
      [LayoutSafeAreaEdge.BOTTOM]
    )
  }
}