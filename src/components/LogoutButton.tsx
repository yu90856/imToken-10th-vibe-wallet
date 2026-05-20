import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@repo/ui/components/button";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@repo/ui/components/alert-dialog";
import { clearWalletSession } from "../lib/session";

interface LogoutButtonProps {
  variant?: "topbar" | "default";
}

export function LogoutButton({ variant = "default" }: LogoutButtonProps) {
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);

  const logout = () => {
    clearWalletSession();
    setOpen(false);
    navigate("/", { replace: true });
  };

  return (
    <AlertDialog open={open} onOpenChange={setOpen}>
      <AlertDialogTrigger asChild>
        {variant === "topbar" ? (
          <button type="button" className="app-topbar__logout-btn">
            登出
          </button>
        ) : (
          <Button type="button" variant="outline" size="sm">
            登出錢包
          </Button>
        )}
      </AlertDialogTrigger>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>確認登出？</AlertDialogTitle>
          <AlertDialogDescription>
            將清除本機錢包資料（加密 keystore 與設定）。您的鏈上資產不受影響，之後需用助記詞或密碼重新導入才能使用此裝置上的錢包。
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>取消</AlertDialogCancel>
          <AlertDialogAction onClick={logout}>確認登出</AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
