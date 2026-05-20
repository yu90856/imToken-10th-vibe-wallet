import type { ReactNode } from "react";

interface ModalProps {
  title: string;
  children: ReactNode;
  primaryLabel: string;
  onPrimary: () => void;
}

export function Modal({ title, children, primaryLabel, onPrimary }: ModalProps) {
  return (
    <div className="modal-overlay" role="dialog" aria-modal="true">
      <div className="modal">
        <h2>{title}</h2>
        {children}
        <button type="button" className="btn btn--primary" onClick={onPrimary}>
          {primaryLabel}
        </button>
      </div>
    </div>
  );
}
