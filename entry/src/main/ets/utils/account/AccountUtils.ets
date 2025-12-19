import { SignInResult } from "@hw-agconnect/auth";

export interface AccountController {
  onSignInSucc: (s: SignInResult) => void;
  onSignInFail: (e: BusinessError) => void;
  onSignOutSucc: () => void;
  onSignOutFail: (e: BusinessError) => void;
}

export interface AccountUtils {
  controller: AccountController;

  init: (controller: AccountController) => void;

  signIn: () => boolean;
  signOut: () => boolean;
}