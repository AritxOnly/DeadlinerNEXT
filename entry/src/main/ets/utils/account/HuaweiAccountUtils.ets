import { AccountController, AccountUtils } from "./AccountUtils";
import auth, { AuthUser } from '@hw-agconnect/auth'
import { hilog } from "@kit.PerformanceAnalysisKit";
import { AuthDefaultUser } from "@hw-agconnect/auth/src/main/ets/k/x4";

export class HuaweiAccountController implements AccountController {
  onSignInSucc: () => void = () => {};
  onSignInFail: (e: BusinessError) => void = (e) => {};
  onSignOutSucc: () => void = () => {};
  onSignOutFail: (e: BusinessError) => void = (e) => {};
}

export class HuaweiAccountUtils implements AccountUtils {
  controller: AccountController = new HuaweiAccountController();

  init: (controller: AccountController) => void = (c) => {
    this.controller = c;
  }

  signIn: () => boolean = this._signIn;

  signOut: () => boolean = this._signOut;

  private _signIn(): boolean {
    auth.signIn({
      autoCreateUser: true,
      "credentialInfo": {
        "kind": 'hwid'
      }
    }).then(signInResult => {
      hilog.info(0x0000, 'testTag', '%{public}s',  `signInHwid success. result: ${signInResult.getUser().getUid()}`);
      this.controller.onSignInSucc();
    })
      .catch((error: BusinessError) => {
        hilog.error(0x0000, 'testTag', '%{public}s', `signInHwid error, Code: ${error.code}, message: ${error.message}`);
        this.controller.onSignInFail(error);
        return false;
      })
    return true;
  }

  private _signOut(): boolean {
    auth.signOut().then(() => {
      this.controller.onSignOutSucc();
    }).catch((error: BusinessError) => {
      this.controller.onSignOutFail(error);
      return false;
    });
    return true;
  }
}