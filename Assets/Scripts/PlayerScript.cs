using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

public class PlayerScript : MonoBehaviour
{
    PlayerControls controls;
    private Rigidbody2D kirbyBody;

    public Vector2 move;
    public bool tryToJump;

    public float moveSpeed = 5f;

    private void Awake()
    {
        controls = new PlayerControls();
        controls.Gameplay.Enable();
        kirbyBody = GetComponent<Rigidbody2D>();

        //Move Input
        controls.Gameplay.Move.performed += ctx => move = ctx.ReadValue<Vector2>();
        controls.Gameplay.Move.canceled += ctx => move = Vector2.zero;

        //Jump Input
        controls.Gameplay.Jump.performed += ctx => tryToJump = true;
        controls.Gameplay.Jump.canceled += ctx => tryToJump = false;
    }
    private void FixedUpdate()
    {
        Debug.Log("move = " + move.ToString());
        Debug.Log("moveSpeed = " + moveSpeed.ToString());

        Vector2 delta = new Vector2(move.x, 0) * Time.deltaTime * moveSpeed;
        Vector2 newPosition = kirbyBody.position + delta;

        Debug.Log("delta = " + delta.ToString());
        Debug.Log("newPosition = " + newPosition.ToString());

        kirbyBody.MovePosition(newPosition);
    }
}
