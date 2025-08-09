import React from "react";
import { forwardRef } from "react";
import clsx from "clsx";
function Grid() {
  return <div>Grid</div>;
}

const Row = forwardRef(
  (
    props: {
      className?: string;
      style?: React.CSSProperties;
      children: React.ReactNode;
      id?: string;
    },
    ref: any,
  ) => {
    const { className, style, id } = props;

    return (
      <div
        id={id}
        ref={ref}
        className={clsx(
          "flex w-full overflow-hidden",
          style?.height ? "flex-none" : "grow",
          className,
        )}
        style={style}
      >
        {props.children}
      </div>
    );
  },
);

function Col(props: {
  className?: string;
  style?: React.CSSProperties;
  children: React.ReactNode;
}) {
  const { className, style } = props;
  return (
    <div
      className={clsx(
        "flex h-full flex-col overflow-x-hidden",
        style?.width ? "flex-none" : "flex-1 grow overflow-hidden",
        className,
      )}
      style={style}
    >
      {props.children}
    </div>
  );
}

export { Col, Row };
export default Grid;
