import type { ReactNode } from "react";

/**
 * Risk UI aligned with token-ui/security/SKILL.md §2.2 severity levels.
 */
import { Alert, AlertDescription, AlertTitle } from "@repo/ui/components/alert";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@repo/ui/components/alert-dialog";

export function SecurityWarningBanner({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <Alert className="border-warning-border bg-warning-surface text-warning-text">
      <AlertTitle>{title}</AlertTitle>
      <AlertDescription>{children}</AlertDescription>
    </Alert>
  );
}

export function SecurityDangerBanner({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <Alert variant="destructive">
      <AlertTitle>{title}</AlertTitle>
      <AlertDescription>{children}</AlertDescription>
    </Alert>
  );
}

export function ScreenshotWarningDialog({
  open,
  onConfirm,
}: {
  open: boolean;
  onConfirm: () => void;
}) {
  if (!open) return null;
  return (
    <AlertDialog open onOpenChange={() => {}}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>安全提醒</AlertDialogTitle>
          <AlertDialogDescription>
            請勿使用截圖保存助記詞，避免被惡意軟體竊取助記詞而導致資產損失。請在無人窺視的環境下手寫抄錄。
          </AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogAction onClick={onConfirm}>我已了解</AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}
