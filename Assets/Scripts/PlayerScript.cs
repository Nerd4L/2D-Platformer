using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.InputSystem;

public class PlayerScript : MonoBehaviour
{
    public ControllerScript controller;
    PlayerControls controls;

    public float moveSpeed = 40f;
    private float horizontalMove = 0f;

    private Vector2 moveInput;
    private bool jumpInput = false;

    private void Awake()
    {
        controls = new PlayerControls();
        controls.Gameplay.Enable();

        //Move Input
        controls.Gameplay.Move.performed += ctx => moveInput = ctx.ReadValue<Vector2>();
        controls.Gameplay.Move.canceled += ctx => moveInput = Vector2.zero;

        //Jump Input
        controls.Gameplay.Jump.performed += ctx => jumpInput = true;
        controls.Gameplay.Jump.canceled += ctx => jumpInput = false;
    }

    // Update is called once per frame
    void Update()
    {
        horizontalMove = moveInput.x * moveSpeed;
    }

    void FixedUpdate()
    {
        // Move our character
        controller.Move(horizontalMove * Time.fixedDeltaTime, jumpInput);
    }
}
